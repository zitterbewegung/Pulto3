import SwiftUI
import Foundation

struct TemplateView: View {
    @State private var selectedCellIndex: Int? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showImportConfirmation = false
    @State private var templateWindows: [TemplateWindow] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    
    // Template window data structure
    struct TemplateWindow: Identifiable {
        let id = UUID()
        let windowId: Int
        let windowType: String
        let exportTemplate: String
        let tags: [String]
        let position: WindowPosition
        let content: String
        let title: String
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if !templateWindows.isEmpty {
                    templateContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Template Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") {
                        showImportConfirmation = true
                    }
                    .disabled(templateWindows.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            loadTemplateWindows()
        }
        .alert("Import Template", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                importAllWindows()
            }
        } message: {
            Text("This will create \(templateWindows.count) new windows in your workspace.")
        }
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading template...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Failed to Load Template")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                loadTemplateWindows()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Template Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The template file could not be found.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var templateContentView: some View {
        HStack(spacing: 0) {
            // Left sidebar - window list
            windowListView
                .frame(width: 350)
                .background(Color(.systemBackground).opacity(0.95))
            
            Divider()
            
            // Right side - preview
            if let selectedIndex = selectedCellIndex,
               selectedIndex < templateWindows.count {
                windowPreviewView(templateWindows[selectedIndex])
            } else {
                templateOverviewView
            }
        }
    }
    
    private var windowListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Template Windows")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Label("\(templateWindows.count) windows", systemImage: "square.stack.3d")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            // Window list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(templateWindows.enumerated()), id: \.element.id) { index, window in
                        TemplateWindowRow(
                            window: window,
                            isSelected: selectedCellIndex == index,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCellIndex = index
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private var templateOverviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Template info
                VStack(alignment: .leading, spacing: 16) {
                    Text("VisionOS Spatial Computing Template")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("A comprehensive template demonstrating spatial data visualization capabilities")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                // Metadata
                metadataSection
                
                // Preview grid
                previewGridSection
                
                // Import button
                VStack {
                    Button(action: { showImportConfirmation = true }) {
                        Label("Import All Windows", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                    
                    Text("This will create \(templateWindows.count) new windows in your workspace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            let uniqueTypes = Set(templateWindows.map { $0.windowType }).count
            let uniqueTags = Set(templateWindows.flatMap { $0.tags }).count
            let uniqueTemplates = Set(templateWindows.map { $0.exportTemplate }).count
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                TemplateMetadataCard(
                    icon: "square.stack.3d",
                    title: "Windows",
                    value: "\(templateWindows.count)",
                    color: .blue
                )
                
                TemplateMetadataCard(
                    icon: "tag",
                    title: "Tags",
                    value: "\(uniqueTags)",
                    color: .green
                )
                
                TemplateMetadataCard(
                    icon: "doc.text",
                    title: "Templates",
                    value: "\(uniqueTemplates)",
                    color: .orange
                )
                
                TemplateMetadataCard(
                    icon: "cube",
                    title: "Window Types",
                    value: "\(uniqueTypes)",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var previewGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Window Previews")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 40)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(templateWindows) { window in
                        TemplateWindowPreviewCard(window: window) {
                            if let index = templateWindows.firstIndex(where: { $0.id == window.id }) {
                                selectedCellIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }

    private func windowPreviewView(_ window: TemplateWindow) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(window.windowType, systemImage: iconForWindowType(window.windowType))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("Window #\(window.windowId)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Label(window.exportTemplate, systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !window.tags.isEmpty {
                        HStack {
                            ForEach(window.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Position info
                positionInfoView(window.position)
                
                // Content preview
                contentPreviewView(window)
                
                // Import button
                Button(action: { importSingleWindow(window) }) {
                    Label("Import This Window", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func positionInfoView(_ position: WindowPosition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position & Size")
                .font(.headline)
            
            HStack(spacing: 24) {
                Label("X: \(Int(position.x))", systemImage: "arrow.left.and.right")
                Label("Y: \(Int(position.y))", systemImage: "arrow.up.and.down")
                Label("Z: \(Int(position.z))", systemImage: "move.3d")
                Spacer()
                Label("\(Int(position.width)) × \(Int(position.height))", systemImage: "aspectratio")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
    }
    
    private func contentPreviewView(_ window: TemplateWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Preview")
                .font(.headline)
            
            ScrollView {
                Text(window.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxHeight: 300)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Methods
    
    private func loadTemplateWindows() {
        isLoading = true
        errorMessage = nil
        templateWindows = []
        
        templateWindows = createSampleTemplateWindows()
        
        if templateWindows.first != nil {
            selectedCellIndex = 0
        }
        
        isLoading = false
    }
    
    private func createSampleTemplateWindows() -> [TemplateWindow] {
        let baseId = 5000
        
        return createFinancialAnalysisTemplate(baseId: baseId) +
               createIoTSensorTemplate(baseId: baseId + 100) +
               createScientificResearchTemplate(baseId: baseId + 200) +
               createBusinessIntelligenceTemplate(baseId: baseId + 300) +
               createMachineLearningTemplate(baseId: baseId + 400)
    }
    
    private func createFinancialAnalysisTemplate(baseId: Int) -> [TemplateWindow] {
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["finance", "analysis", "overview"],
                position: WindowPosition(x: -400, y: 200, z: -50, width: 600, height: 400),
                content: """
                # Financial Market Analysis Dashboard
                
                ## Executive Summary
                This workspace analyzes **S&P 500 stock performance** over the past 12 months, focusing on:
                
                - **Daily price movements** and volume patterns
                - **Risk assessment** using volatility metrics  
                - **Portfolio correlation** analysis
                - **Technical indicators** (RSI, MACD, Bollinger Bands)
                
                ## Key Findings
                - Average daily return: **+0.12%**
                - Maximum drawdown: **-8.4%** 
                - Sharpe ratio: **1.24**
                - Best performing sector: **Technology** (+15.2%)
                
                ## Data Sources
                - Yahoo Finance API (real-time quotes)
                - FRED Economic Data (market indicators)
                - SEC filings (fundamental data)
                """,
                title: "Financial Analysis Overview"
            ),
            
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["finance", "timeseries", "visualization"],
                position: WindowPosition(x: 100, y: 150, z: 0, width: 800, height: 500),
                content: """
                # Stock Price Analysis & Technical Indicators
                
                import pandas as pd
                import numpy as np
                import matplotlib.pyplot as plt
                import yfinance as yf
                from datetime import datetime, timedelta
                
                # Fetch S&P 500 data for the last year
                end_date = datetime.now()
                start_date = end_date - timedelta(days=365)
                
                # Download multiple stocks for comparison
                tickers = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA']
                stock_data = {}
                
                for ticker in tickers:
                    stock_data[ticker] = yf.download(ticker, start=start_date, end=end_date)
                
                # Create comprehensive visualization
                fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 12))
                
                # 1. Price comparison (normalized)
                for ticker in tickers:
                    normalized_price = stock_data[ticker]['Close'] / stock_data[ticker]['Close'].iloc[0]
                    ax1.plot(normalized_price.index, normalized_price, label=ticker, linewidth=2)
                
                ax1.set_title('Normalized Stock Price Performance', fontsize=14, fontweight='bold')
                ax1.set_ylabel('Normalized Price')
                ax1.legend()
                ax1.grid(True, alpha=0.3)
                
                print("Portfolio analysis complete")
                """,
                title: "Stock Market Analysis"
            ),
            
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "DataFrame Viewer",
                exportTemplate: "Pandas DataFrame",
                tags: ["finance", "data", "metrics"],
                position: WindowPosition(x: -200, y: -100, z: 25, width: 900, height: 450),
                content: """
                # Financial Metrics & Portfolio Data
                
                import pandas as pd
                import numpy as np
                from datetime import datetime, timedelta
                
                # Generate realistic financial portfolio data
                np.random.seed(42)
                
                # Create a realistic portfolio with 25 holdings
                companies = [
                    'Apple Inc', 'Microsoft Corp', 'Amazon.com Inc', 'Alphabet Inc', 'Tesla Inc',
                    'Meta Platforms', 'NVIDIA Corp', 'Netflix Inc', 'Adobe Inc', 'Salesforce Inc'
                ]
                
                tickers = [
                    'AAPL', 'MSFT', 'AMZN', 'GOOGL', 'TSLA',
                    'META', 'NVDA', 'NFLX', 'ADBE', 'CRM'
                ]
                
                # Generate realistic financial data
                portfolio_data = []
                for i, (company, ticker) in enumerate(zip(companies, tickers)):
                    # Realistic stock prices and market caps
                    base_price = np.random.uniform(50, 500)
                    market_cap = base_price * np.random.uniform(1e9, 10e9) / 1e9
                    
                    portfolio_data.append({
                        'Company': company,
                        'Ticker': ticker,
                        'Current_Price': round(base_price, 2),
                        'Market_Cap_B': round(market_cap, 1),
                        'YTD_Return_Pct': round(np.random.normal(8.5, 25), 1),
                        'Portfolio_Weight_Pct': round(np.random.uniform(0.5, 8), 2),
                        'Sector': np.random.choice(['Technology', 'Consumer', 'Healthcare'])
                    })
                
                # Create DataFrame
                portfolio_df = pd.DataFrame(portfolio_data)
                print("Portfolio data generated")
                display(portfolio_df)
                """,
                title: "Portfolio Holdings"
            ),
            
            TemplateWindow(
                windowId: baseId + 4,
                windowType: "Model Metric Viewer",
                exportTemplate: "NumPy Array",
                tags: ["finance", "metrics", "kpis", "performance"],
                position: WindowPosition(x: -100, y: 350, z: 50, width: 550, height: 400),
                content: """
                # Financial Model Performance Dashboard
                
                ## Real-Time Trading Model Metrics
                
                ### Model Performance (Last 24h)
                - **Accuracy**: 78.4% (↑2.1%)
                - **Precision**: 82.1% (↑1.8%)
                - **Recall**: 74.6% (↓0.3%)
                - **F1-Score**: 0.783 (↑0.009)
                
                ### Financial Performance
                - **Total P&L**: +$47,382 (↑$3,921)
                - **Win Rate**: 64.2% (↑1.4%)
                - **Average Win**: +$1,247
                - **Average Loss**: -$891
                - **Risk-Adjusted Return**: 2.34%
                
                ### Model Health
                - **Prediction Latency**: 23ms (avg)
                - **Data Freshness**: 1.2s delay
                - **Model Drift Score**: 0.034 (Low)
                - **Feature Importance Stability**: 94.1%
                """,
                title: "Trading Model KPIs"
            )
        ]
    }

    private func createIoTSensorTemplate(baseId: Int) -> [TemplateWindow] {
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["iot", "sensors", "monitoring"],
                position: WindowPosition(x: -350, y: 180, z: -40, width: 650, height: 420),
                content: """
                # Smart Building IoT Monitoring System
                
                ## System Overview
                Real-time monitoring of **47 IoT sensors** deployed across a 12-story commercial building:
                
                ### Sensor Network
                - **Environmental**: Temperature, Humidity, Air Quality (CO₂, PM2.5)
                - **Energy**: Power consumption, HVAC efficiency, Lighting usage
                - **Security**: Motion detection, Door access, Camera feeds
                
                ## Current Status
                - **Active Sensors**: 45/47 (95.7% uptime)
                - **Data Points/Hour**: ~16,900
                - **Alert Threshold Breaches**: 3 (last 24h)
                - **Energy Efficiency Score**: 87.2/100
                """,
                title: "IoT System Overview"
            ),
            
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["iot", "timeseries", "environmental"],
                position: WindowPosition(x: 150, y: 120, z: 10, width: 850, height: 550),
                content: """
                # Environmental Sensor Data Analysis
                
                import pandas as pd
                import numpy as np
                import matplotlib.pyplot as plt
                from datetime import datetime, timedelta
                
                # Generate realistic IoT sensor data
                np.random.seed(42)
                
                # Time series data generation
                dates = pd.date_range(start='2024-01-01', periods=100, freq='D')
                temperatures = 22 + 3 * np.sin(np.arange(100) * 2 * np.pi / 30) + np.random.normal(0, 0.5, 100)
                humidity = 45 + np.random.normal(0, 5, 100)
                
                # Create visualization
                fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
                
                ax1.plot(dates, temperatures, 'r-', label='Temperature (°C)')
                ax1.set_title('Temperature Monitoring')
                ax1.legend()
                ax1.grid(True, alpha=0.3)
                
                ax2.plot(dates, humidity, 'b-', label='Humidity (%)')
                ax2.set_title('Humidity Monitoring')
                ax2.legend()
                ax2.grid(True, alpha=0.3)
                
                plt.tight_layout()
                plt.show()
                """,
                title: "Environmental Monitoring"
            ),
            
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "DataFrame Viewer",
                exportTemplate: "Pandas DataFrame",
                tags: ["iot", "sensors", "inventory"],
                position: WindowPosition(x: -180, y: -120, z: 30, width: 950, height: 480),
                content: """
                # IoT Sensor Network Inventory & Status
                
                import pandas as pd
                import numpy as np
                from datetime import datetime, timedelta
                
                # Generate sensor network data
                np.random.seed(123)
                
                sensor_types = ['Temperature', 'Humidity', 'CO2', 'Motion', 'Light']
                zones = ['Lobby', 'Office-A', 'Office-B', 'Conference', 'Server-Room']
                
                sensor_data = []
                for i in range(50):
                    sensor_data.append({
                        'Sensor_ID': f'IOT-{1000+i:04d}',
                        'Type': np.random.choice(sensor_types),
                        'Zone': np.random.choice(zones),
                        'Status': np.random.choice(['Active', 'Warning', 'Offline'], p=[0.85, 0.10, 0.05]),
                        'Battery_Level': np.random.randint(10, 100),
                        'Last_Reading': datetime.now() - timedelta(minutes=np.random.randint(1, 60))
                    })
                
                sensor_df = pd.DataFrame(sensor_data)
                print("IoT Sensor Network Status")
                display(sensor_df)
                """,
                title: "Sensor Network Status"
            )
        ]
    }

    private func createScientificResearchTemplate(baseId: Int) -> [TemplateWindow] {
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["research", "chemistry", "analysis"],
                position: WindowPosition(x: -380, y: 160, z: -30, width: 680, height: 450),
                content: """
                # Protein Folding Dynamics Research Project
                
                ## Research Objective
                Investigation of **β-amyloid protein aggregation** kinetics under varying temperature and pH conditions for Alzheimer's disease research.
                
                ### Experimental Design
                - **Sample Size**: 144 protein samples across 12 conditions
                - **Temperature Range**: 25°C - 45°C (5°C intervals)
                - **pH Range**: 6.0 - 8.0 (0.4 unit intervals)
                - **Observation Period**: 72 hours with measurements every 2 hours
                
                ## Key Findings
                - **Optimal Aggregation**: pH 6.4, 37°C (physiological relevance)
                - **Lag Phase Duration**: 8.2 ± 1.4 hours under optimal conditions
                - **Growth Rate**: 0.34 ± 0.05 h⁻¹ exponential phase
                
                ## Research Team
                - Dr. Sarah Chen (Principal Investigator)
                - Dr. Michael Rodriguez (Structural Biologist)  
                - Lisa Park (Graduate Research Assistant)
                """,
                title: "Research Overview"
            ),
            
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["research", "kinetics", "analysis"],
                position: WindowPosition(x: 180, y: 100, z: 20, width: 900, height: 580),
                content: """
                # Protein Aggregation Kinetics Analysis
                
                import pandas as pd
                import numpy as np
                import matplotlib.pyplot as plt
                
                # Generate realistic protein aggregation data
                np.random.seed(42)
                
                # Time points and conditions
                time_points = np.linspace(0, 72, 37)
                temperatures = [25, 30, 35, 37, 40, 45]
                
                fig, axes = plt.subplots(2, 2, figsize=(12, 10))
                
                # Kinetic curves for different temperatures
                for temp in temperatures:
                    # Simulate aggregation kinetics
                    lag_time = 20 - (temp - 25) * 0.5
                    max_signal = 8000 * (1 + (temp - 37) * 0.02)
                    
                    signal = []
                    for t in time_points:
                        if t < lag_time:
                            s = 200 + np.random.normal(0, 30)
                        else:
                            growth = 1 - np.exp(-0.3 * (t - lag_time))
                            s = 200 + max_signal * growth + np.random.normal(0, 100)
                        signal.append(max(200, s))
                    
                    axes[0,0].plot(time_points, signal, label=f'{temp}°C', linewidth=2)
                
                axes[0,0].set_title('Aggregation Kinetics by Temperature')
                axes[0,0].set_xlabel('Time (hours)')
                axes[0,0].set_ylabel('ThT Fluorescence (AU)')
                axes[0,0].legend()
                axes[0,0].grid(True, alpha=0.3)
                
                plt.tight_layout()
                plt.show()
                
                print("Protein aggregation analysis complete")
                """,
                title: "Kinetics Analysis"
            ),
            
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "DataFrame Viewer",
                exportTemplate: "Pandas DataFrame",
                tags: ["research", "experimental", "data"],
                position: WindowPosition(x: -150, y: -140, z: 40, width: 1000, height: 500),
                content: """
                # Experimental Data Collection & Sample Tracking
                
                import pandas as pd
                import numpy as np
                from datetime import datetime, timedelta
                
                # Generate experimental dataset
                np.random.seed(456)
                
                temperatures = [25, 30, 35, 37, 40, 45]
                ph_values = [6.0, 6.4, 6.8, 7.2, 7.6, 8.0]
                
                experimental_data = []
                sample_id = 1
                
                for temp in temperatures:
                    for ph in ph_values:
                        for replicate in range(1, 5):
                            experimental_data.append({
                                'Sample_ID': f'S{sample_id:04d}',
                                'Temperature_C': temp,
                                'pH': ph,
                                'Replicate': replicate,
                                'Protein_Batch': 'AB42-2024-03',
                                'Initial_Purity_Pct': round(np.random.normal(98.5, 1.2), 1),
                                'Experimenter': np.random.choice(['Dr. Chen', 'Lisa Park', 'James Liu']),
                                'Status': 'Complete'
                            })
                            sample_id += 1
                
                experiment_df = pd.DataFrame(experimental_data)
                print("Experimental Dataset Overview")
                display(experiment_df.head(20))
                """,
                title: "Experimental Data"
            )
        ]
    }

    private func createBusinessIntelligenceTemplate(baseId: Int) -> [TemplateWindow] {
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["business", "analytics", "kpis"],
                position: WindowPosition(x: -400, y: 140, z: -20, width: 700, height: 480),
                content: """
                # SaaS Business Performance Dashboard
                
                ## Executive Summary
                Analysis of **SaaS platform performance** across key business metrics for Q3 2024.
                
                ### Key Performance Indicators
                - **Monthly Recurring Revenue (MRR)**: $2.4M (+18.2% QoQ)
                - **Customer Acquisition Cost (CAC)**: $247 (-12.3% vs Q2)
                - **Customer Lifetime Value (CLV)**: $3,840 (+8.7% vs Q2)
                - **Net Revenue Retention**: 112% (Target: 110%)
                
                ### Growth Metrics
                - **New Customers**: 1,247 (+22.1% QoQ)
                - **Churned Customers**: 89 (-15.7% QoQ)  
                - **Net New MRR**: $432K (+31.4% QoQ)
                
                ## Market Segmentation Performance
                - **Enterprise (>500 employees)**: 42% of revenue, 8% churn
                - **Mid-Market (50-500 employees)**: 35% of revenue, 12% churn
                - **SMB (<50 employees)**: 23% of revenue, 18% churn
                """,
                title: "Business Intelligence Overview"
            ),
            
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["business", "revenue", "growth"],
                position: WindowPosition(x: 200, y: 80, z: 30, width: 950, height: 600),
                content: """
                # SaaS Business Metrics & Growth Analysis
                
                import pandas as pd
                import numpy as np
                import matplotlib.pyplot as plt
                from datetime import datetime, timedelta
                
                # Generate realistic SaaS business data
                np.random.seed(789)
                
                # Date range (18 months)
                start_date = datetime(2023, 1, 1)
                dates = pd.date_range(start=start_date, periods=18, freq='M')
                months = np.arange(18)
                
                # MRR growth
                base_mrr = 1.2e6
                growth_rate = 0.08
                seasonality = 0.05 * np.sin(2 * np.pi * months / 12)
                mrr = base_mrr * np.exp(growth_rate * months) * (1 + seasonality)
                
                # Create visualization
                fig, axes = plt.subplots(2, 2, figsize=(15, 10))
                
                axes[0,0].plot(dates, mrr/1e6, 'g-', linewidth=3, marker='o')
                axes[0,0].set_title('Monthly Recurring Revenue')
                axes[0,0].set_ylabel('MRR ($M)')
                axes[0,0].grid(True, alpha=0.3)
                
                plt.tight_layout()
                plt.show()
                
                print(f"Current MRR: ${mrr[-1]:,.0f}")
                """,
                title: "Revenue Analytics"
            ),
            
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "DataFrame Viewer",
                exportTemplate: "Pandas DataFrame",
                tags: ["business", "customers", "crm"],
                position: WindowPosition(x: -120, y: -160, z: 50, width: 1050, height: 520),
                content: """
                # Customer Analytics & Segmentation Database
                
                import pandas as pd
                import numpy as np
                from datetime import datetime, timedelta
                
                # Generate customer database
                np.random.seed(321)
                
                segments = {
                    'Enterprise': {'count': 340, 'avg_arr': 28000},
                    'Mid-Market': {'count': 1250, 'avg_arr': 8500},
                    'SMB': {'count': 2890, 'avg_arr': 2400}
                }
                
                customer_data = []
                customer_id = 10001
                
                for segment, config in segments.items():
                    for _ in range(min(config['count'], 100)):  # Limit for demo
                        customer_data.append({
                            'Customer_ID': customer_id,
                            'Segment': segment,
                            'ARR': round(np.random.normal(config['avg_arr'], config['avg_arr'] * 0.3), 2),
                            'Status': np.random.choice(['Active', 'At Risk', 'Churned'], p=[0.85, 0.12, 0.03]),
                            'Region': np.random.choice(['North America', 'Europe', 'Asia-Pacific'])
                        })
                        customer_id += 1
                
                customers_df = pd.DataFrame(customer_data)
                print("Customer Analytics Overview")
                display(customers_df.head(20))
                """,
                title: "Customer Analytics"
            )
        ]
    }

    private func createMachineLearningTemplate(baseId: Int) -> [TemplateWindow] {
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["ml", "ai", "models"],
                position: WindowPosition(x: -350, y: 120, z: -10, width: 650, height: 400),
                content: """
                # Machine Learning Model Performance Analysis
                
                ## Project Overview
                Evaluation of **neural network models** for image classification on CIFAR-10 dataset.
                
                ### Model Architecture
                - **Base Model**: ResNet-50 with transfer learning
                - **Input Shape**: 224x224x3 RGB images
                - **Output Classes**: 10 categories
                - **Total Parameters**: 25.6M (trainable: 2.1M)
                
                ### Training Configuration
                - **Dataset Split**: 80% train, 15% validation, 5% test
                - **Batch Size**: 32
                - **Learning Rate**: 0.001 with cosine annealing
                - **Epochs**: 50 with early stopping
                
                ## Performance Metrics
                - **Test Accuracy**: 94.2% (±0.3%)
                - **Precision**: 94.1% (macro-averaged)
                - **Recall**: 94.0% (macro-averaged)
                - **F1-Score**: 94.0%
                - **Training Time**: 3.2 hours on RTX 4090
                """,
                title: "ML Model Overview"
            ),
            
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["ml", "training", "metrics"],
                position: WindowPosition(x: 150, y: 60, z: 15, width: 900, height: 550),
                content: """
                # Model Training Analysis & Performance Metrics
                
                import pandas as pd
                import numpy as np
                import matplotlib.pyplot as plt
                
                # Generate realistic training history
                np.random.seed(42)
                epochs = 50
                
                # Training curves
                train_loss = []
                val_loss = []
                train_acc = []
                val_acc = []
                
                for epoch in range(epochs):
                    # Training loss decreases
                    base_train_loss = 2.5 * np.exp(-epoch/15) + 0.1
                    train_loss.append(base_train_loss + np.random.normal(0, 0.05))
                    
                    # Validation loss with some overfitting
                    if epoch < 30:
                        base_val_loss = 2.7 * np.exp(-epoch/18) + 0.15
                    else:
                        base_val_loss = 0.25 + (epoch-30) * 0.01
                    val_loss.append(base_val_loss + np.random.normal(0, 0.03))
                    
                    # Accuracy curves
                    train_acc.append(min(0.98, 0.1 + 0.88 * (1 - np.exp(-epoch/12))))
                    val_acc.append(min(0.95, 0.1 + 0.85 * (1 - np.exp(-epoch/15))))
                
                # Create visualization
                fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
                
                ax1.plot(range(1, epochs+1), train_loss, 'b-', label='Training Loss')
                ax1.plot(range(1, epochs+1), val_loss, 'r-', label='Validation Loss')
                ax1.set_title('Model Loss Over Time')
                ax1.legend()
                ax1.grid(True, alpha=0.3)
                
                ax2.plot(range(1, epochs+1), [acc*100 for acc in train_acc], 'b-', label='Training Accuracy')
                ax2.plot(range(1, epochs+1), [acc*100 for acc in val_acc], 'r-', label='Validation Accuracy')
                ax2.set_title('Model Accuracy Over Time')
                ax2.legend()
                ax2.grid(True, alpha=0.3)
                
                plt.tight_layout()
                plt.show()
                
                print(f"Final Training Accuracy: {train_acc[-1]*100:.1f}%")
                print(f"Final Validation Accuracy: {val_acc[-1]*100:.1f}%")
                """,
                title: "Training Analytics"
            ),
            
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "Model Metric Viewer",
                exportTemplate: "NumPy Array",
                tags: ["ml", "performance", "monitoring"],
                position: WindowPosition(x: -100, y: 300, z: 25, width: 600, height: 450),
                content: """
                # Real-Time Model Performance Dashboard
                
                ## Production Model Metrics (Last 24h)
                
                ### Inference Performance
                - **Average Latency**: 23.4ms (↓2.1ms)
                - **95th Percentile**: 45.2ms (↓3.8ms)
                - **99th Percentile**: 78.1ms (↑1.2ms)
                - **Throughput**: 1,247 requests/min (↑156)
                - **GPU Utilization**: 67.2% (↑4.3%)
                
                ### Model Accuracy Monitoring
                - **Online Accuracy**: 93.8% (↓0.4%)
                - **Data Drift Score**: 0.089 (Low)
                - **Feature Drift**: 0.034 (Very Low)
                - **Prediction Confidence**: 0.924 avg (↑0.012)
                
                ### Resource Usage
                - **Memory Usage**: 4.2GB / 8GB (52.5%)
                - **CPU Usage**: 34.7% (4 cores)
                - **Cache Hit Rate**: 89.4% (↑2.1%)
                
                ### Model Health Score: 94.2/100
                - **Availability**: 99.97% ✅
                - **Performance**: 95.1% ✅  
                - **Accuracy**: 93.8% ⚠️
                - **Resource Efficiency**: 91.3% ✅
                """,
                title: "Model Monitoring"
            )
        ]
    }

    private func importAllWindows() {
        for window in templateWindows {
            importWindow(window)
        }
        dismiss()
    }

    private func importSingleWindow(_ window: TemplateWindow) {
        importWindow(window)
        dismiss()
    }

    private func importWindow(_ window: TemplateWindow) {
        let windowType: WindowType
        switch window.windowType {
        case "Charts":
            windowType = .charts
        case "Spatial Editor":
            windowType = .spatial
        case "DataFrame Viewer":
            windowType = .column
        case "Model Metric Viewer":
            windowType = .volume 
        default:
            windowType = .spatial
        }
        
        var state = WindowTypeManager.WindowState()
        if let exportTemplate = ExportTemplate(rawValue: window.exportTemplate) {
            state.exportTemplate = exportTemplate
        }
        state.content = window.content
        state.tags = window.tags
        state.lastModified = Date()
        
        if windowType == .column {
            state.dataFrameData = DataFrameData(
                columns: ["Sensor_ID", "Temperature", "Humidity", "Status"],
                rows: [
                    ["SENSOR_001", "22.5", "45.2", "Active"],
                    ["SENSOR_002", "23.1", "44.8", "Active"],
                    ["SENSOR_003", "21.9", "46.1", "Inactive"],
                    ["SENSOR_004", "22.8", "45.5", "Active"],
                    ["SENSOR_005", "23.3", "44.3", "Maintenance"]
                ],
                dtypes: [
                    "Sensor_ID": "string",
                    "Temperature": "float",
                    "Humidity": "float",
                    "Status": "string"
                ]
            )
        }
        
        if windowType == .spatial && window.title.contains("3D") {
            state.pointCloudData = PointCloudDemo.generateSpherePointCloudData(radius: 10.0, points: 500)
        }
        
        if windowType == .volume {
            state.content = """
# Model Performance Metrics
# Generated from template

import numpy as np
import matplotlib.pyplot as plt

# Sample metrics data
metrics = {
    "accuracy": 0.94,
    "latency_ms": 125,
    "throughput_rps": 250,
    "memory_mb": 512,
    "cpu_percent": 35
}

print("Model Metrics:")
for key, value in metrics.items():
    print(f"{key}: {value}")
"""
        }
        
        _ = windowManager.createWindow(windowType, id: window.windowId, position: window.position)
        
        windowManager.updateWindowState(window.windowId, state: state)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            openWindow(value: window.windowId)
        }
    }
}

struct TemplateWindowRow: View {
    let window: TemplateView.TemplateWindow
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconForWindowType(window.windowType))
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .accentColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.windowType)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Text(window.exportTemplate)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    Text("Window #\(window.windowId)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : Color.gray.opacity(0.3))
                }
                
                Spacer()
                
                if !window.tags.isEmpty {
                    Label("\(window.tags.count)", systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }
}

struct TemplateMetadataCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TemplateWindowPreviewCard: View {
    let window: TemplateView.TemplateWindow
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconForWindowType(window.windowType))
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    
                    Spacer()
                    
                    Text("#\(window.windowId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(window.windowType)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(window.exportTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(window.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if !window.tags.isEmpty {
                    HStack {
                        Image(systemName: "tag")
                            .font(.caption)
                        Text(window.tags.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .frame(width: 250, height: 200)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
    
    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }
}

struct TemplateView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateView()
            .frame(width: 1000, height: 700)
    }
}