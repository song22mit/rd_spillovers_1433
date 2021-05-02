
cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

import delimited data/raw/Jensen-Kletzer-2005-table-4.csv, clear
ren ïnaics naics

gen ratio = nontradable / tradable
drop if naics == ""
sort ratio

drop ratio
collapse (sum) *tradable, by(description) 
gen ratio = nontradable / tradable
sort ratio

/*
naics	description	nontradable	tradable	ratio
22	Utilities	.76	.18	4.222222
44	Retail Trade	5.9	1.32	4.469697
72	Accommodation	4.52	1	4.52
45	Retail Trade	2.91	.37	7.864865
62	Health Care/Social	10.9	.25	43.6
61	Education	8.75	.1	87.5
4M	Retail Trade	.62	0	
23	Construction	6.86	0	

*/




//------------------------------construction and retail------------------------------------------
//seed the append loop
clear
set obs 1
gen x=.
save data/intermediate/qcew_allcounties_constructionretail_post01, replace

//read in and append QCEW data
forvalues yr = 2001(1)2019 {
    display `yr'
	if `yr' <= 2015{
		import delimited "data/raw/QCEW/`yr'.annual 23 Construction.csv", clear
	}
	else {
		import delimited "data/raw/QCEW/`yr'.annual 23 NAICS 23 Construction.csv", clear
	}
	
	//keep only totals (not by ownership)
	rename area_fips COUNTY
	
	drop oty* //overtime stats, not relevant and not available
	drop lq* //location quotients: only relevant for per-industry stats
	
	tostring(disclosure_code), replace
	tostring(industry_code), replace

	append using data/intermediate/qcew_allcounties_constructionretail_post01
	save data/intermediate/qcew_allcounties_constructionretail_post01, replace
	
	
	if `yr' <= 2015{
		import delimited "data/raw/QCEW/`yr'.annual 44-45 Retail trade.csv", clear
	}
	else {
		import delimited "data/raw/QCEW/`yr'.annual 44-45 NAICS 44-45 Retail trade.csv", clear
	}
	
	//keep only totals (not by ownership)
	rename area_fips COUNTY
	
	drop oty* //overtime stats, not relevant and not available
	drop lq* //location quotients: only relevant for per-industry stats
	
	tostring(disclosure_code), replace

	append using data/intermediate/qcew_allcounties_constructionretail_post01
	save data/intermediate/qcew_allcounties_constructionretail_post01, replace
}

//discard statewide observations
tab agglvl_title
keep if agglvl_title == "County, NAICS Sector -- by ownership sector" //not using MSA data, using county data and crosswalking for consistent MSA definition since redraw post census

//NOTE: disclosure_code = N means missing data
recode annual* avg_annual_pay total_annual_wages taxable (0 = .) if disclosure_code == "N"
tab disclosure_code own_title

/*
gen missing = 1 if disclosure_code == "N"
drop disclosure_code own_title
collapse (sum) annual_avg_estabs_count annual_avg_emplvl total_annual_wages missing, by(COUNTY year)
tab missing
*/
//NOTE: TOO MANY MISSING VALUES SO ONLY LOOK AT PRIVATE ESTABS
keep if own_title == "Private"


//drop seed observation
drop if year == .
drop x
save data/intermediate/qcew_allcounties_constructionretail_private_post01, replace



// --------------- merge qcew with ffrdc data, adjust for inflation-------------------------
use data/intermediate/qcew_allcounties_constructionretail_private_post01, clear
merge m:1 year COUNTY using data/intermediate/ffrdcrd_county_summary
tab year _merge
keep if year >= 2001
drop _merge

merge m:1 year using data/intermediate/inflation_adjustment
tab year _merge
keep if year >= 2001
drop _merge
foreach dollar_var of varlist total_annual_wages-dataFederal {
    replace `dollar_var' = `dollar_var'/dollarvalue
}

save data/intermediate/merged_allcounties_constructionretail_private_post01, replace

//--------------crosswalk to and summarize by MSA------------------------
use data/intermediate/merged_allcounties_constructionretail_private_post01, clear
merge m:1 COUNTY using data/intermediate/county-to-msa
drop if _merge == 2

//investigate if all FFRDCs are in MSAs
list if ffrdc_count != . & msacode == "" //there is one FFRDC in Barnwell County, SC that is not in a MSA. TO DO: 
drop if msacode == "" //omit that FFRDC

//summarize by MSA
collapse (sum) dataTotal dataFederal ffrdc_count annual_avg_estabs_count annual_avg_emplvl total_annual_wages, by(industry_code msacode msatitle msatype year)
gen avg_annual_pay = total_annual_wages/annual_avg_emplvl


//look into only Metro, not Micro
tab ffrdc msatype
list msatitle year if msatype == "Micro" & ffrdc_count > 0 //Alamogordo, NM 2010+, Los Alamos, NM throughout 2001-2019 each with one ffrdc_count

keep if msatype == "Metro"
save data/intermediate/merged_MetroMSAs_constructionretail_private_post01, replace

