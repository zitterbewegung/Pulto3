//
//  PlotlyWebView.swift
//  SwiftChartsWWDC24
//
//  Created by Joshua Herman on 2/16/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import WebKit

// A SwiftUI wrapper for WKWebView
struct PlotlyWebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure the WKWebView with JavaScript enabled
        let config = WKWebViewConfiguration()
        
        // Use the new API for enabling JavaScript content
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Load the HTML content that includes your Plotly.js graph
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// The main content view that uses the PlotlyWebView
struct PlotlyView: View {
    var body: some View {
        PlotlyWebView(htmlContent: htmlContent)
            .edgesIgnoringSafeArea(.all)
    }

    // Your HTML content with Plotly.js
    private var htmlContent: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
            <style>
                /* Ensure the chart fills the view */
                html, body { margin: 0; padding: 0; height: 100%; width: 100%; }
            </style>
        </head>
        <body>
            <div id="chart" style="width:100%;height:100%;"></div>
            <script>
                var data = [{
                    x: [1, 2, 3, 4, 5],
                    y: [1, 6, 3, 6, 1],
                    type: 'scatter'
                }];
                var layout = { title: 'Plotly.js Graph in VisionOS' };
                Plotly.newPlot('chart', data, layout);
            </script>
        </body>
        </html>
        """
    }
}
#Preview {
    PlotlyView()
}