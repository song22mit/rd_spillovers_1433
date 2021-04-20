cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

use data/intermediate/merged_MetroMSAs_allind_post01, clear


keep if year == 2001 | year == 2019
keep year msacode msatitle ffrdc_count

reshape wide ffrdc_count, i(msacode msatitle) j(year)

keep if ffrdc_count2019 != ffrdc_count2001
drop ffrdc*
save data/intermediate/changed_ffrdc_count_MetroMSAs_post01, replace


use data/intermediate/merged_MetroMSAs_allind_post01, clear
merge m:1 msacode msatitle using data/intermediate/changed_ffrdc_count_MetroMSAs_post01
keep if _merge == 3
//TO DO: investigate these

replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000000 
label variable annual_avg_emplvl "Annual average of total employment (millions"
replace dataFederal = dataFederal / 1000000
label variable dataFederal "Total federal FFRDC funding received (millions 2019$)"

twoway line dataFederal year if msacode == "C1258", title("Federal FFRDC funding in" "Baltimore-Columbia-Towson, MD") 
twoway line dataFederal year if msacode == "C2706", title("Federal FFRDC funding in" "Ithaca, NY") 

twoway line avg_annual_pay year if msacode == "C1258", title("Average annual pay" "Baltimore-Columbia-Towson, MD") 
twoway line avg_annual_pay year if msacode == "C2706", title("Average annual pay" "Ithaca, NY") 

twoway line annual_avg_emplvl year if msacode == "C1258", title("Average annual employment level" "Baltimore-Columbia-Towson, MD") 
twoway line annual_avg_emplvl year if msacode == "C2706", title("Average annual employment level" "Ithaca, NY") 