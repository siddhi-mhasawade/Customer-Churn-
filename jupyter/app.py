import streamlit as st
import joblib
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from lime import lime_tabular
import shap

# --- 1. SETUP & LOADING ---
st.set_page_config(page_title="ChurnAI | Retention Dashboard", layout="wide")

@st.cache_resource
def load_assets():
    # Load trained artifacts
    model = joblib.load('best_churn_model.pkl')
    scaler = joblib.load('scaler.pkl')
    features = joblib.load('feature_names.pkl')
    test_df = pd.read_csv("../datasets/telco_testing_dataset.csv")
    
    # PRE-CALCULATE GLOBAL SHAP ONCE 
    # We use a random_state so the bars NEVER flip-flop.
    bg_raw = test_df.head(200).copy().rename(columns={'tenure': 'Tenure'})
    bg_encoded = pd.get_dummies(bg_raw)
    
    # Ensure all feature columns exist in background data
    for col in features:
        if col not in bg_encoded.columns:
            bg_encoded[col] = 0
    
    bg_scaled = scaler.transform(bg_encoded[features])
    
    # Calculate Global SHAP values one time only
    explainer_shap = shap.LinearExplainer(model, bg_scaled)
    global_shap_vals = explainer_shap.shap_values(bg_scaled)
    
    return model, scaler, features, test_df, global_shap_vals, bg_scaled

# Global SHAP is now locked in
model, scaler, feature_names, test_df, global_shap_values, background_scaled = load_assets()

# --- 2. SIDEBAR CONTROLS ---
st.sidebar.image("https://cdn-icons-png.flaticon.com/512/2103/2103633.png", width=100)
st.sidebar.title("Customer Intelligence")

# Button to pull a random customer from the full test set
if st.sidebar.button("Pick a Customer"):
    st.session_state['sample'] = test_df.sample(1).iloc[0]

# Default to the first row if no button clicked
s = st.session_state.get('sample', test_df.iloc[0])

st.sidebar.markdown("---")
# Sliders allow you to simulate "What If" scenarios for the selected customer
tenure = st.sidebar.slider("Tenure (Months)", 0, 72, int(s['tenure']), key=f"t_{s.name}")
monthly = st.sidebar.slider("Monthly Bill ($)", 18.0, 120.0, float(s['MonthlyCharges']), key=f"m_{s.name}")

# --- 3. PREDICTION LOGIC ---
# Construct the input row for the model
input_row = pd.DataFrame(0, index=[0], columns=feature_names)
input_row['Tenure'], input_row['MonthlyCharges'] = tenure, monthly
input_row['TotalCharges'] = tenure * monthly

# Scale the specific individual's data
input_scaled = scaler.transform(input_row)
prob = model.predict_proba(input_scaled)[0][1]

# --- 4. PROFESSIONAL UI ---
st.title("🛡️ Customer Retention Strategy Portal")
st.markdown(f"**Analyzing Customer ID:** `{s.get('customerID', 'Unknown')}`")

col_metric, col_advice = st.columns([1, 2])

with col_metric:
    # Logic for Risk Categorization
    if prob < 0.3:
        level, color, icon = "LOW", "green", "✅"
    elif prob < 0.45:
        level, color, icon = "MEDIUM", "orange", "⚠️"
    else:
        level, color, icon = "HIGH", "red", "🚨"
    
    st.markdown(f"<h3 style='text-align: center; color: {color};'>{icon} {level} RISK</h3>", unsafe_allow_html=True)
    st.metric("Churn Probability", f"{prob:.1%}")
    st.progress(prob)

with col_advice:
    st.subheader("📋 Retention Strategy")
    if level == "HIGH":
        st.warning("🔥 **Critical Intervention Required:** Customer is high-risk. Recommend immediate loyalty discount or contract lock-in.")
    elif level == "MEDIUM":
        st.info("⚡ **Proactive Engagement:** Suggested upsell of Tech Support or Streaming add-ons to increase service stickiness.")
    else:
        st.success("💎 **Healthy Account:** Low churn risk. Focus on maintaining current service quality.")

st.markdown("---")
tab1, tab2 = st.tabs(["🔍 Why this Score? (LIME)", "📈 Global Feature Trends"])

with tab1:
    st.write("### Individual Risk Factors (Local Interpretation)")
    # LIME recalculates every time the sliders move or customer changes
    explainer = lime_tabular.LimeTabularExplainer(
        background_scaled, 
        feature_names=feature_names, 
        class_names=['Stay', 'Churn'], 
        mode='classification'
    )
    exp = explainer.explain_instance(input_scaled[0], model.predict_proba, num_features=5)
    
    c1, c2 = st.columns(2)
    with c1:
        st.write("#### Key Drivers for this Case")
        for feat, weight in exp.as_list():
            status = "🚩" if weight > 0 else "✅"
            st.write(f"{status} **{feat}**")
    with c2:
        # LIME Bar chart
        fig_lime = exp.as_pyplot_figure()
        plt.tight_layout()
        st.pyplot(fig_lime)

with tab2:
    st.write("### Model Decision Logic (SHAP Global)")
    st.markdown("> **Note:** This chart represents the model's overall intelligence across the entire dataset. It shows which features generally drive churn for all customers.")
    
    # SHAP uses the pre-calculated, cached global values
    # This will remain STATIC and STABLE across interactions
    fig_shap, ax_shap = plt.subplots(figsize=(10, 6))
    shap.summary_plot(
        global_shap_values, 
        background_scaled, 
        feature_names=feature_names, 
        plot_type="bar", 
        show=False
    )
    plt.tight_layout()
    st.pyplot(fig_shap)