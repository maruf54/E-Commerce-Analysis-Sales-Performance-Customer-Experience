# Power BI data model & DAX measures

## Model

```
Calendar (Date)  ──1:*──▶  v_order_summary (order_date)
v_order_summary (order_id)  ──1:*──▶  v_category_sales (order_id)
```

Calendar is related only to `v_order_summary`. Filters reach `v_category_sales` through
the order_id relationship. A second direct Calendar link would create an ambiguous path.

## Calendar table

```DAX
Calendar = ADDCOLUMNS(
    CALENDAR(DATE(2016,9,1), DATE(2018,10,31)),
    "Year", YEAR([Date]),
    "Month", FORMAT([Date], "MMM"),
    "MonthNum", MONTH([Date]),
    "YearMonth", FORMAT([Date], "YYYY-MM")
)
```

## Measures

```DAX
Total Revenue = CALCULATE(SUM(v_order_summary[payment_value]), v_order_summary[order_status] = "delivered")

Total Orders = CALCULATE(DISTINCTCOUNT(v_order_summary[order_id]), v_order_summary[order_status] = "delivered")

Avg Order Value = DIVIDE([Total Revenue], [Total Orders])

Avg Review Score = AVERAGE(v_order_summary[review_score])

Late Delivery % =
DIVIDE(
    CALCULATE([Total Orders], v_order_summary[delivery_status] = "Late"),
    CALCULATE([Total Orders], v_order_summary[delivery_status] <> "Not delivered")
)

Revenue MoM % =
VAR cur = [Total Revenue]
VAR prev = CALCULATE([Total Revenue], DATEADD('Calendar'[Date], -1, MONTH))
RETURN DIVIDE(cur - prev, prev)

Category Revenue = SUM(v_category_sales[price])   -- stored in v_category_sales
```

**Validation:** I checked the Total Revenue, Total Orders and AOV cards against SQL Q1.
They match.
