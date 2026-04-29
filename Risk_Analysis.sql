/*=========================================================
Project: Fraud Risk Analysis (SQL)
Purpose: This project evaluates transaction risk using a rule based scoring model built from transaction amount, login behavior,
and transaction channel. The objective is to identify high risk patterns, measure financial exposure, and support fraud monitoring decisions.
Author: Aliza Acharya

-----------------------------------------------------------
SECTION 2: RISK MODEL DEFINITION
----------------------------------------------------------
Risk Score Logic:
--A transaction receives points based on three indicators:
--1. TransactionAmount > 500
Reason: Higher value transactions create greater financial exposure.
Score Contribution: 2 points
2. LoginAttempts > 2
Reason: Repeated login attempts may suggest account compromise or suspicious access behavior.
Score Contribution:3 points
3. Channel = 'Online'
Reason: Online transactions generally carry higher operational risk than branch based transactions.
Score Contribution: 2 points
4. Risk Category Logic:
--High Risk   : Risk_Score >= 5
--Medium Risk : Risk_Score >= 3
--Low Risk    : Otherwise
Interpretation: This model does not claim confirmed fraud. It prioritizes transactions based on risk signals so analysts can focus on the most suspicious cases first.

=============================================================
SECTION 3: ADD  COLUMNS TO TABLE
=============================================================
*/
ALTER TABLE dbo.FinancialFraudAnalysis
ADD Risk_Score INT, Risk_Category VARCHAR(20);

--#Update Risk Score
Update dbo.FinancialFraudAnalysis
SET Risk_Score = 
	(case when TransactionAmount > 500 THEN 2 ELSE 0 END +
	CASE WHEN LoginAttempts > 2 then 3 else 0 end +
	case when Channel = 'Online' Then 2 Else 0 end);

--#Update Risk_Category
Update dbo.FinancialFraudAnalysis
SET Risk_Category = CASE 
WHEN Risk_Score >=5 THEN 'High Risk'
WHEN Risk_Score >=3 THEN 'Medium Risk'
ELSE 'Low Risk'
END; 

/*
Validation Check:
Confirming that Risk_Score and Risk_Category were created correctly.
*/

SELECT TOP 20
    TransactionID,
    TransactionAmount,
    LoginAttempts,
    Channel,
    Risk_Score,
    Risk_Category
FROM dbo.FinancialFraudAnalysis;
/*
-----------------------------------------------------------------------------
SECTION 4: OVERALL RISK DISTRIBUTION
-----------------------------------------------------------------------------

Objective
Assess the distribution of transactions across risk levels to evaluate the effectiveness of the risk scoring model and identify where fraud monitoring efforts should be focused.
*/
SELECT
    Risk_Category,
    COUNT(*) AS Total_Transactions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS Percentage_of_Total
FROM dbo.FinancialFraudAnalysis
GROUP BY Risk_Category
ORDER BY
    CASE Risk_Category
        WHEN 'High Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        ELSE 3
    END;
/*
Key Finding:
Transactions are predominantly Low Risk (90.5%), while High Risk accounts for only 1.83%, indicating that elevated risk is concentrated within a small subset of transactions.

Business Implication
Prioritize monitoring of high-risk transactions, as they require immediate attention, while lower-risk activity can be managed through automated controls.

=============================================================
SECTION 5: CHANNEL RISK ANALYSIS
=============================================================
Objective
Evaluate risk concentration across transaction channels to identify where fraud exposure is highest and guide channel-specific monitoring strategies.
*/
SELECT
    Channel,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) AS High_Risk_Transactions,
    ROUND(
        100.0 * SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS High_Risk_Percentage
FROM dbo.FinancialFraudAnalysis
GROUP BY Channel
ORDER BY High_Risk_Percentage DESC;
/*
Key Finding
The Online channel shows the highest proportion of high-risk transactions, indicating greater vulnerability compared to ATM and branch channels.

Business Implication
Strengthen fraud controls in the Online channel, including enhanced authentication and monitoring, while maintaining standard controls for lower-risk channels.

=============================================================
SECTION 6: LOCATION RISK ANALYSIS
=============================================================
Objective

Analyze geographic distribution of transaction risk to identify high-risk locations and prioritize fraud monitoring based on both risk concentration and financial exposure.
*/
SELECT
    Location,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) AS High_Risk_Transactions,
    ROUND(
        100.0 * SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS High_Risk_Percentage,
    SUM(CASE WHEN Risk_Category = 'High Risk' THEN TransactionAmount ELSE 0 END) AS High_Risk_Value
FROM dbo.FinancialFraudAnalysis
GROUP BY Location
ORDER BY High_Risk_Value DESC, High_Risk_Percentage DESC;
/*
Key Finding

Certain locations show a higher concentration of high-risk transactions, while others contribute more significantly to total high-risk value, indicating variation in both risk intensity and financial exposure across regions.

Business Implication

Prioritize fraud monitoring in locations with both high risk rates and high financial exposure to maximize impact and reduce potential losses.

=============================================================
SECTION 7: LOGIN BEHAVIOR ANALYSIS
=============================================================

Objective
Assess the relationship between login attempts and transaction risk to determine whether repeated access behavior is a strong indicator of fraud.
*/
SELECT
    LoginAttempts,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) AS High_Risk_Transactions,
    ROUND(100.0 * SUM(CASE WHEN Risk_Category = 'High Risk' THEN 1 ELSE 0 END) / COUNT(*), 2) AS High_Risk_Percentage
FROM dbo.FinancialFraudAnalysis
GROUP BY LoginAttempts
ORDER BY LoginAttempts;
/*
Key Finding
Transactions with 1–2 login attempts show no high-risk activity, while risk increases sharply from 3 attempts onward, which indicates that login behavior is a critical indicator of suspicious activity.
=============================================================
SECTION 8: FINANCIAL IMPACT BY RISK LEVEL
=============================================================
Objective: Measure the financial exposure across risk levels to understand whether high-risk activity carries meaningful transaction value. */
SELECT
    Risk_Category,
    COUNT(*) AS Total_Transactions,
    SUM(TransactionAmount) AS Total_Transaction_Value,
    AVG(TransactionAmount) AS Avg_Transaction_Value,
    MAX(TransactionAmount) AS Max_Transaction_Value
FROM dbo.FinancialFraudAnalysis
GROUP BY Risk_Category
ORDER BY
    CASE Risk_Category
        WHEN 'High Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        ELSE 3
    END;
/*
Key Finding:
High Risk transactions account for only 917 transactions, but represent about $330.7K in transaction value with an average transaction value of $360.66. Medium Risk transactions have the highest average value at $651.57, showing that financial exposure is not limited to High Risk alone.

Business Implication:
Prioritize High Risk transactions for immediate review, while also monitoring Medium Risk transactions because they carry higher average transaction value and may create meaningful financial exposure.

=============================================================
SECTION 9: HIGH RISK TRANSACTION PROFILE
=============================================================
Objective: To identify the most common characteristics of high-risk transactions by analyzing channel, location, and login behavior together. */

SELECT
    Channel,
    Location,
    LoginAttempts,
    COUNT(*) AS High_Risk_Transactions,
    AVG(TransactionAmount) AS Avg_High_Risk_Amount,
    SUM(TransactionAmount) AS Total_High_Risk_Value
FROM dbo.FinancialFraudAnalysis
WHERE Risk_Category = 'High Risk'
GROUP BY Channel, Location, LoginAttempts
ORDER BY High_Risk_Transactions DESC, Total_High_Risk_Value DESC;
/*
Key Findings:
High risk transactions are primarily concentrated in online channel, with locations such as San Diego, Philadelphia, and Charlotte appearing among the highest high-risk transaction counts. 
Several of these patterns also involve 3 or more login attempts, reinforcing login behavior as a key risk signal.

Business Implications:

Prioritize review rules for online transactions with elevated login attempts in high-risk locations, as these combinations represent recurring fraud patterns that can support faster investigation and monitoring.

=============================================================
SECTION 10: PRIORITY REVIEW QUEUE
=============================================================
Objective

Prioritize high-risk transactions for review to help fraud teams focus on the most critical cases efficiently. */

SELECT TOP 25
    TransactionID,
    AccountID,
    TransactionAmount,
    TransactionDate,
    Channel,
    Location,
    LoginAttempts,
    Risk_Score,
    Risk_Category
FROM dbo.FinancialFraudAnalysis
WHERE Risk_Category = 'High Risk'
ORDER BY Risk_Score DESC, TransactionAmount DESC;
/*
Key Finding
The highest priority transactions are concentrated in the Online channel, primarily from locations such as San Diego, with consistently high risk scores and elevated transaction amounts, indicating strong signals of suspicious activity.

Business Implication
--Focus immediate investigation on these top-ranked transactions to enable faster detection and response, reducing potential financial loss and improving fraud management efficiency.

=============================================================
SECTION 11: FINAL ANALYTICAL SUMMARY
=============================================================
This project develops a rule-based fraud risk scoring model using transaction amount, login behavior, and transaction channel to identify high-risk activity and support fraud monitoring decisions.

## Tools & Techniques
SQL (T-SQL) is used to build a rule-based risk model and analyze transaction data using aggregation, conditional logic, and window functions to identify fraud patterns and prioritize high-risk transactions.
### Key Insights
- Most transactions fall under the Low Risk category (90.5%), while High Risk transactions represent only 1.83%, indicating that fraud risk is concentrated within a small portion of transactions.  
- Online transactions show the highest concentration of high-risk activity (4.5%), significantly higher than ATM and Branch channels.  
- Certain locations contribute disproportionately to high-risk transaction value, highlighting potential geographic fraud hotspots.  
- Transactions with more than two login attempts show a sharp increase in risk, making login behavior a strong indicator of suspicious activity.  
- Although High Risk transactions are fewer in number, they represent meaningful financial exposure (~$330K), while Medium Risk transactions have the highest average transaction value.  
- High-risk transactions are primarily concentrated in the Online channel, often combined with elevated login attempts and specific locations, forming recurring fraud patterns.  

### Business Recommendation
- Focus fraud monitoring efforts on high-value Online transactions with elevated login attempts in high-risk locations.
- Use the prioritized review queue to enable faster investigation, improve operational efficiency, and reduce potential financial losses.
