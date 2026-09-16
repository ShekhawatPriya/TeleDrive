import 'dart:io';

/// Run after the UI preview tests. Produces a portable, offline review gallery.
void main() {
  final directory = Directory('build/modernization');
  if (!directory.existsSync()) {
    stderr.writeln(
      'Generate previews with the command in docs/design-workflow.md first.',
    );
    exitCode = 1;
    return;
  }
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final cards = files
      .map((file) {
        final name = file.uri.pathSegments.last;
        final title = name.replaceAll('.png', '').replaceAll('-', ' ');
        final platform = name.contains('-iOS-')
            ? 'ios'
            : name.contains('-android-')
            ? 'android'
            : 'shared';
        final mode = name.contains('-dark') ? 'dark' : 'light';
        final area = name.startsWith('login-')
            ? 'login'
            : name.startsWith('folder-actions-')
            ? 'actions'
            : name.startsWith('full-drive-') || name.startsWith('full-photos-')
            ? 'navigation'
            : 'other';
        return '<article data-platform="$platform" data-mode="$mode" data-area="$area"><h2>$title</h2>'
            '<a href="$name" target="_blank"><img loading="lazy" src="$name" alt="$title"></a></article>';
      })
      .join('\n');
  File('${directory.path}/index.html').writeAsStringSync('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>TeleDrive · Design review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f4f5f8;color:#172034;font:15px/1.5 system-ui,sans-serif}
header{max-width:1440px;margin:auto;padding:40px 24px 24px}h1{font-size:40px;letter-spacing:-1.5px;margin:8px 0}
p{max-width:780px;color:#535b6b}small{letter-spacing:2px}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}
select{font:inherit;padding:12px 18px;border:1px solid #cbd0d9;border-radius:12px;background:white}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:28px;max-width:1440px;padding:0 24px 48px;margin:auto}
article{min-width:0}article[hidden]{display:none}h2{font-size:14px;text-transform:capitalize;font-weight:600}
img{display:block;width:100%;border-radius:20px;box-shadow:0 12px 40px #16243b12;border:1px solid #d7dce5}
footer{padding:24px;text-align:center;color:#535b6b}a{color:#245bdd}a:focus-visible,select:focus-visible{outline:3px solid #245bdd;outline-offset:4px}
</style>
<header><small>TELEDRIVE / FRONTEND REVIEW</small><h1>Designed for the way you use it.</h1>
<p>Rendered Flutter screens with isolated fixture data. These are local design previews, not screenshots of a live account or proof of native iOS execution. Open a screen to inspect it at full size.</p>
<nav><label>Screen <select id="area"><option value="all">All screens</option><option value="navigation">Navigation</option><option value="login">Login flow</option><option value="actions">Folder actions</option></select></label><label>Platform <select id="platform"><option value="all">All platforms</option><option value="ios">iOS</option><option value="android">Android</option><option value="shared">Shared components</option></select></label>
<label>Appearance <select id="mode"><option value="all">Light + dark</option><option value="light">Light</option><option value="dark">Dark</option></select></label></nav></header>
<main>$cards</main>
<footer>Preview photo: <a href="https://commons.wikimedia.org/wiki/File:Fronalpstock_big.jpg">Fronalpstock big · Hannes Röst</a>,
<a href="https://creativecommons.org/licenses/by-sa/3.0/">CC BY-SA 3.0</a>. Cropped for preview; photograph adaptations retain this license. Not bundled in the app.</footer>
<script>
const platform=document.querySelector('#platform'),mode=document.querySelector('#mode'),area=document.querySelector('#area');
function filter(){document.querySelectorAll('article').forEach(c=>{c.hidden=(platform.value!=='all'&&platform.value!==c.dataset.platform)||(mode.value!=='all'&&mode.value!==c.dataset.mode)||(area.value!=='all'&&area.value!==c.dataset.area);});}
platform.addEventListener('change',filter);mode.addEventListener('change',filter);area.addEventListener('change',filter);
</script></html>''');
  stdout.writeln(
    'Created ${directory.path}/index.html with ${files.length} previews.',
  );
}
