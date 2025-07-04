# Data Analysis Script
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from sklearn.linear_model import LinearRegression

def analyze_sales_data():
    """
    Analyze sales data and generate insights
    """
    # Sample data
    data = {
        'month': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
        'sales': [1000, 1200, 1100, 1300, 1500, 1400],
        'marketing_spend': [200, 250, 220, 280, 320, 290]
    }
    
    df = pd.DataFrame(data)
    
    # Create visualizations
    plt.figure(figsize=(12, 5))
    
    plt.subplot(1, 2, 1)
    plt.plot(df['month'], df['sales'], marker='o')
    plt.title('Monthly Sales Trend')
    plt.xlabel('Month')
    plt.ylabel('Sales ($)')
    
    plt.subplot(1, 2, 2)
    plt.scatter(df['marketing_spend'], df['sales'])
    plt.title('Sales vs Marketing Spend')
    plt.xlabel('Marketing Spend ($)')
    plt.ylabel('Sales ($)')
    
    # Linear regression
    X = df[['marketing_spend']]
    y = df['sales']
    model = LinearRegression()
    model.fit(X, y)
    
    print(f"R-squared: {model.score(X, y):.3f}")
    print(f"Slope: {model.coef_[0]:.2f}")
    
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    analyze_sales_data()
