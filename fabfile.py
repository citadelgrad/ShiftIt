################################################################################
## Configuration
################################################################################
import os
import tempfile

try:
    import sh

    gpg = sh.Command('gpg')
except (ImportError, Exception) as exc:
    def gpg(*args, **kwargs):
        raise NotImplementedError('the sh module is not installed or gpg command not found; unable to use gpg-encrypted keys')


class DecryptedFiles(object):
    tempfiles = []

    @classmethod
    def get_decrypted_key_path(cls, path):
        """
        Returns the path to a decrypted key

        When the given path ends with `.gpg`, the file will be decrypted into a temporary file.

        Args:
            path (str): path to the decrypted key

        Returns:
            str: the path to a decrypted key
        """
        if not path.endswith('.gpg'):
            return path

        fh = tempfile.NamedTemporaryFile()
        cls.tempfiles.append(fh)

        result = gpg('-d', path)

        fh.write(result.stdout)
        fh.flush()

        return fh.name

SHIFTIT_GITHUB_USER = os.environ['SHIFTIT_GITHUB_USER']
SHIFTIT_GITHUB_REPO = os.environ['SHIFTIT_GITHUB_REPO']

proj_name = 'ShiftIt'
proj_info_plist = 'ShiftIt-Info.plist'
proj_src_dir = 'ShiftIt'

# GitHub token for release automation
proj_github_token_file = DecryptedFiles.get_decrypted_key_path(os.environ.get('SHIFTIT_GITHUB_TOKEN', os.path.expanduser('~/Keys/ShiftIt/github.token')))

# Sparkle sign_update tool path - reads EdDSA key from macOS Keychain by default
# The private key is stored in Keychain under service "https://sparkle-project.org" with account "ed25519"
proj_sign_update_tool = os.environ.get('SHIFTIT_SIGN_UPDATE', os.path.join(os.path.dirname(__file__), 'ShiftIt', 'bin', 'sign_update'))

release_notes_template_html = '''
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
    <body>
        <h1>{{proj_name}} version {{proj_version}}</h1>

        {{#has_issues}}
        <h2>Issues closed</h2>
        <ul>
        {{#issues}}
            <li><a href="{{html_url}}"><b>#{{number}}</b></a> - {{title}}</li>
        {{/issues}}
        </ul>
        {{/has_issues}}

        More information about this release can be found on <a href="{{milestone_url}}">github</a>.
        <br/><br/>
        If you find any bugs please report them on <a href="http://github.com/citadelgrad/ShiftIt/issues">github</a>.
    </body>
</html>
'''.strip()

release_notes_template_md = '''
{{#has_issues}}
## Issues closed
{{#issues}}
- [#{{number}}]({{html_url}}) - {{title}}
{{/issues}}
{{/has_issues}}

More information about this release can be found on [github]({{milestone_url}}).

If you find any bugs please report them on [github](http://github.com/citadelgrad/ShiftIt/issues).
'''.strip()

appcast_template = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
   <channel>
      <title>{{proj_name}} Changelog</title>
      <link>{{proj_appcast_url}}</link>
      <language>en</language>
      <item>
         <title>{{proj_name}} version {{proj_version}}</title>
         <sparkle:releaseNotesLink>
            {{proj_release_notes_url}}
         </sparkle:releaseNotesLink>
         <pubDate>{{date}}</pubDate>
         <enclosure
            url="{{download_url}}"
            sparkle:version="{{proj_version}}"
            length="{{download_size}}"
            type="application/octet-stream"
            sparkle:edSignature="{{download_signature}}" />
         <sparkle:minimumSystemVersion>14.6</sparkle:minimumSystemVersion>
      </item>
   </channel>
</rss>
'''.strip()

from invoke import task, run
from invoke.context import Context

# Compatibility layer for Fabric 1.x to 3.x migration
def local(cmd, capture=False):
    result = run(cmd, hide=capture, warn=True)
    if capture:
        return result.stdout
    return result

def puts(msg):
    print(msg)

def green(msg):
    return f"\033[92m{msg}\033[0m"

class lcd:
    def __init__(self, path):
        import os
        self.path = path
        self.old_path = None
    def __enter__(self):
        import os
        self.old_path = os.getcwd()
        os.chdir(self.path)
    def __exit__(self, *args):
        import os
        os.chdir(self.old_path)

class settings:
    def __init__(self, warn_only=False):
        self.warn_only = warn_only
    def __enter__(self):
        pass
    def __exit__(self, *args):
        pass

def execute(func):
    ctx = Context()
    return func(ctx)

from xml.etree import ElementTree

import pystache
import github3
import tempfile
import base64
import datetime

################################################################################
## Code
################################################################################

def _find(f, seq):
  """Return first item in sequence where f(item) == True."""

  for item in seq:
    if f(item):
      return item

def _get_bundle_version(info_plist):
    version = local('defaults read %s CFBundleVersion' % info_plist, capture=True)
    return version.strip()

def _get_milestone():
    milestone = _find(lambda m: proj_version.startswith(m.title), shiftit.iter_milestones())
    if not milestone:
        raise Exception('Unable to find milestone: %s' % proj_version)

    return milestone

def _gen_release_notes(template):
    def _convert(i):
        return {
            'number': i.number,
            'html_url': i.html_url,
            'title': i.title,
        }

    milestone = _get_milestone()

    closed_issues = list(shiftit.iter_issues(milestone=milestone.number, state='closed'))
    closed_issues.sort(key=lambda i: i.closed_at)

    release_notes = dict(
        has_issues = len(closed_issues) > 0,
        issues = closed_issues,
        proj_name=proj_name,
        proj_version=proj_version,
        milestone_url='https://github.com/citadelgrad/ShiftIt/issues?milestone=%d' % milestone.number,
        )

    return pystache.render(template, release_notes)

def _load_github_token():
    with open(proj_github_token_file,'rt') as f:
        return f.read().strip()

################################################################################
## Project settings
################################################################################

proj_src_dir = os.path.join(os.getcwd(), proj_src_dir)
proj_build_dir = os.path.join(os.getcwd(), 'build')
proj_app_dir = os.path.join(proj_src_dir,'build','Release',proj_name+'.app')
proj_public_key = os.path.join(proj_src_dir,'dsa_pub.pem')
proj_info_plist = os.path.join(proj_src_dir, proj_info_plist)

proj_version = _get_bundle_version(proj_info_plist)
proj_archive_name = proj_name + '-' + proj_version + '.zip'
proj_archive_path = os.path.join(proj_build_dir, proj_archive_name)

proj_download_url = 'https://github.com/citadelgrad/ShiftIt/releases/download/version-%s/%s' % (proj_version, proj_archive_name)
proj_release_notes_url = 'http://htmlpreview.github.com/?https://raw.github.com/citadelgrad/ShiftIt/master/release/release-notes-'+proj_version+'.html'
proj_release_notes_html_file = os.path.join(os.getcwd(),'release','release-notes-'+proj_version+'.html')
proj_appcast_file = os.path.join(os.getcwd(),'release','appcast.xml')
proj_github_token = _load_github_token()

################################################################################
## Globals
################################################################################

github = github3.login(token=proj_github_token)
shiftit = github.repository(SHIFTIT_GITHUB_USER, SHIFTIT_GITHUB_REPO)

################################################################################
## Tasks
################################################################################

@task
def info(ctx):
    '''
    Output all the build properties
    '''

    print('Build info:')
    for (k,v) in [(k,v) for (k,v) in globals().items() if k.startswith('proj_')]:
        print("\t%s: %s" % (k[len('proj_'):],v))

@task
def build(ctx):
    '''
    Makes a build by executing xcodebuild
    '''

    with lcd(proj_src_dir):
        local('xcodebuild -target %s -configuration Release' % proj_name)

@task
def archive(ctx):
    '''
    Archives build
    '''

    execute(build)
    local('ditto -ck --keepParent %s %s' % (proj_app_dir, proj_archive_path))

@task
def release_notes(ctx):
    with open(proj_release_notes_html_file,"w") as f:
        f.write(_gen_release_notes(release_notes_template_html))
        puts('Written '+proj_release_notes_html_file)

@task
def appcast(ctx):
    '''
    Prepare the release: sign the build, generate appcast, generate release notes, commit and push.
    '''

    milestone = _get_milestone()

    # verify that appcast URL matches
    tree = ElementTree.parse(proj_info_plist)
    root = tree.getroot().find('dict')
    elem = list(root.findall('*'))
    appcast_url = _find(lambda kv: kv[0].text == 'SUFeedURL', zip(*[iter(elem)]*2))[1].text.strip()

    # dependencies
    execute(archive)
    execute(release_notes)

    # Sign with EdDSA using Sparkle's sign_update tool
    # The private key is automatically read from macOS Keychain (service: https://sparkle-project.org, account: ed25519)
    sign_result = local('%s %s' % (proj_sign_update_tool, proj_archive_path), capture=True)
    signature = sign_result.strip()

    # appcast properties
    appcast = dict(
        proj_name=proj_name,
        proj_appcast_url=appcast_url,
        proj_version=proj_version,
        proj_release_notes_url=proj_release_notes_url,
        date=datetime.datetime.now().strftime('%a, %d %b %G %T %z'),
        download_url=proj_download_url,
        download_size=os.path.getsize(proj_archive_path),
        download_signature=signature,
    )

    with open(proj_appcast_file,"w") as f:
        f.write(pystache.render(appcast_template, appcast))

@task
def release(ctx):
    '''
    Prepares the release to github
    '''

    with settings(warn_only=True):
        if not local('git diff-index --quiet HEAD --').return_code:
            puts('Warning: there are pending changes in the repository. Run git status')

    milestone = _get_milestone()
    open_issues = list(shiftit.iter_issues(milestone=milestone.number, state='open'))
    if len(open_issues) > 0:
        puts('Warning: there are still open issues')
        for i in open_issues:
            print('\t * #%s: %s' % (i.number, i.title))


    execute(appcast)

    puts('\n')
    puts('='*100)
    puts(green('1. Commit appcast and release notes'))
    puts('message: "Added appcast and release notes for the ShiftIt %s release"' % proj_version)
    puts(green('2. Finnish the git flow'))
    puts(green('3. Close milestone at: https://github.com/citadelgrad/ShiftIt/milestones'))
    puts(green('4. Release at: https://github.com/citadelgrad/ShiftIt/releases and drafts a new release with:'))
    puts('-'*100)
    puts('tag: version-'+proj_version)
    puts('title: '+proj_version)
    puts('description:')
    puts(_gen_release_notes(release_notes_template_md))
    puts('-'*100)
