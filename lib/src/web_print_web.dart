// Web implementation: opens HTML in a new browser tab using dart:html.
import 'dart:convert';
import 'dart:html' as html;

void openHtmlInNewTab(String htmlContent, {bool autoPrint = false}) {
  // Create a Blob and open an object URL in a new tab. This avoids issues
  // with data: URIs getting blocked or truncated in some browsers.
  try {
    var content = htmlContent;
    if (autoPrint) {
      // Inject a small toolbar with a Download HTML button and trigger print on load.
      final toolbar = '''
        <div id="__ss_toolbar" style="position:fixed;top:8px;right:8px;z-index:2147483647;background:rgba(0,0,0,0.7);color:#fff;padding:8px;border-radius:8px;font-family:sans-serif">
          <button id="__ss_download" style="margin-right:8px;padding:6px 8px;">Download HTML</button>
          <button id="__ss_print" style="padding:6px 8px;">Print</button>
        </div>
        <script>
          (function(){
            function downloadHtml(){
              try{
                const blob = new Blob([document.documentElement.outerHTML], {type:'text/html'});
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a'); a.href = url; a.download = 'resume.html'; document.body.appendChild(a); a.click(); setTimeout(()=>{URL.revokeObjectURL(url); a.remove();},1000);
              }catch(e){}
            }
            document.addEventListener('DOMContentLoaded', function(){
              var dl = document.getElementById('__ss_download');
              var pr = document.getElementById('__ss_print');
              if(dl) dl.addEventListener('click', downloadHtml);
              if(pr) pr.addEventListener('click', function(){ try{ window.print(); }catch(e){} });
              // Try to auto-open print dialog after a short delay
              setTimeout(function(){ try{ window.print(); }catch(e){} }, 500);
            });
          })();
        </script>
      ''';

      // Insert toolbar right after opening <body> tag if present, otherwise prepend
      final bodyOpen = RegExp(r'<body[^>]*>', caseSensitive: false);
      final m = bodyOpen.firstMatch(content);
      if (m != null) {
        final insertPos = m.end;
        content = content.substring(0, insertPos) +
            toolbar +
            content.substring(insertPos);
      } else {
        content = toolbar + content;
      }
    }
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    // Revoke the object URL after a short delay to free memory.
    Future.delayed(const Duration(seconds: 5), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });
  } catch (e) {
    // Fallback to a data URI if Blobs aren't supported.
    final dataUri =
        Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8)
            .toString();
    html.window.open(dataUri, '_blank');
  }
}
