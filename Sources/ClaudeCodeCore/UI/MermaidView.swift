import SwiftUI
import WebKit

struct MermaidView: NSViewRepresentable {
  
  class Coordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
      webView.evaluateJavaScript("console.log('Mermaid diagram loaded successfully');") { _, error in
        if let error {
          print("Debug - webView Error: \(error)")
        }
      }
    }
    
    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
      print("Debug - Navigation Error: \(error)")
    }
  }
  
  let diagram: String
  
  func makeNSView(context: Context) -> WKWebView {
    let webView = WKWebView()
    webView.allowsMagnification = true
    webView.navigationDelegate = context.coordinator
    loadMermaidDiagram(into: webView)
    return webView
  }
  
  func updateNSView(_ webView: WKWebView, context _: Context) {
    loadMermaidDiagram(into: webView)
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  private func loadMermaidDiagram(into webView: WKWebView) {
    let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js"></script>
            <style>
                body { 
                    margin: 0; 
                    padding: 20px;
                    background-color: #f5f5f7;
                    min-height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                .mermaid {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    width: 100%;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                }
                /* Dark mode support */
                @media (prefers-color-scheme: dark) {
                    body {
                        background-color: #1c1c1e;
                    }
                    .mermaid {
                        filter: invert(1) hue-rotate(180deg);
                    }
                }
                .cluster rect {
                    fill: #f8f9fa !important;
                    stroke: #e9ecef !important;
                    stroke-width: 2px !important;
                    rx: 5px !important;
                    ry: 5px !important;
                }
                .cluster text {
                    fill: #495057 !important;
                    font-weight: 600 !important;
                    font-size: 16px !important;
                }
                .node rect {
                    fill: #e7f5ff !important;
                    stroke: #74c0fc !important;
                    stroke-width: 2px !important;
                    rx: 5px !important;
                    ry: 5px !important;
                }
                .node text {
                    fill: #1864ab !important;
                    font-size: 14px !important;
                }
                .edgePath path {
                    stroke: #adb5bd !important;
                    stroke-width: 2px !important;
                }
                .edgeLabel {
                    color: #495057 !important;
                    font-size: 12px !important;
                }
                .edgePath marker {
                    fill: #adb5bd !important;
                }
            </style>
        </head>
        <body>
            <div class="mermaid">
            \(diagram)
            </div>
            <script>
                mermaid.initialize({
                    startOnLoad: true,
                    theme: 'default',
                    securityLevel: 'loose',
                    fontFamily: '-apple-system',
                    flowchart: {
                        useMaxWidth: true,
                        htmlLabels: true
                    }
                });
            </script>
        </body>
        </html>
        """
    
    webView.loadHTMLString(html, baseURL: nil)
  }
}
