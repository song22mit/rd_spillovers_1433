cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

//defense instrument----------------

//import defense total budget data
import delimited data/raw/API_MS.MIL.XPND.CD_DS2_en_csv_v2_2254956.csv, rowrange(5:) clear
keep if v1 == "United States" | v1 == "Country Name"
xpose, clear
ren v1 year
ren v2 total_military_spending
drop if year == . | total_military_spending == .
save data/intermediate/total_us_military_spending, replace





//obtain DoD FFRDC funding
use data/intermediate/ffrdcrd_all, clear
keep if question == "Federal agency"
keep if row == "Department of Defense" //homeland security too maybe?
keep year ZIP data inst_city

//crosswalk to county
merge m:1 ZIP using data/intermediate/zip_to_county_unique, keepusing(COUNTY)
drop if _merge == 2

//handcode counties where there is no unique county for that zip
replace COUNTY = "25017" if inst_city == "Lexington"
replace COUNTY = "51013" if inst_city == "Arlington"
replace COUNTY = "51510" if inst_city == "Alexandria"
replace COUNTY = "51003" if inst_city == "Charlottesville"
replace COUNTY = "17043" if inst_city == "Argonne"
replace COUNTY = "48453" if inst_city == "Austin"
replace COUNTY = "16019" if inst_city == "Idaho Falls"
replace COUNTY = "35028" if inst_city == "Los Alamos"
replace COUNTY = "06037" if inst_city == "Santa Monica"
replace COUNTY = "06001" if inst_city == "Livermore"
drop if ZIP == "99999"

drop _merge

//crosswalk to MSA
merge m:1 COUNTY using data/intermediate/county-to-msa
drop if _merge == 2
keep if msatype == "Metro"



collapse (sum) data, by(year msacode msatitle)


//adjust for inflation
merge m:1 year using data/intermediate/inflation_adjustment
keep if _merge == 3
replace data = data / dollarvalue
drop _merge dollarvalue

//export
preserve
ren data defense_funding_thousands
save data/intermediate/defense_funding_thousands, replace
restore

//merge in total defense budget data (current USD)
merge m:1 year using data/intermediate/total_us_military_spending
keep if _merge == 3
drop _merge

//calculate budget ratios
gen budget_ratio = data * 1000 / total_military_spending

//calculate average across 2016-2019
drop total_military_spending data
reshape wide budget_ratio, i(msacode msatitle) j(year)
recode budget_ratio201* (. = 0)
egen avg_budget_ratio = rowmean(budget_ratio201*)

//note: only 19 MSAs reported nonzero defense funding anytime in 2016-2019
drop budget_ratio201*
save data/intermediate/defense_budget_ratios, replace






//defense instrument cont'd ---------------------------------
use data/intermediate/merged_MetroMSAs_allind_post01, clear

encode msacode, gen(msa_factor)

replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000
label variable annual_avg_emplvl "Annual average of total employment (thousands)"
replace federal_funding = federal_funding / 1000
label variable federal_funding "Total federal FFRDC funding received (millions 2019$)"

merge m:1 msacode msatitle using data/intermediate/defense_budget_ratios
recode avg_budget_ratio (. = 0)
drop _merge

merge m:1 year using data/intermediate/total_us_military_spending
keep if _merge == 3
drop _merge

gen defense_funding_instrument = avg_budget_ratio * total_military_spending

//summary stats
preserve
collapse (sum) federal_funding (mean) total_military_spending, by(year)
replace total_military_spending = total_military_spending/1000000000
label variable federal_funding "FFRDC Funding"
label variable total_military_spending "Military Spending"
graph twoway (line total_military_spending year, yaxis(1) ytitle("Total US Military Spending (Billions Current $)", axis(1))) (line federal_funding year, yaxis(2) ytitle("Total federal FFRDC funding (millions 2019$)", axis(2))), title("Comovement of US Military Spending" "and federal FFRDC funding")
graph export "output/defense_instrument_comovement.png", as(png) replace
restore


//take logs
gen log_avg_annual_pay = ln(avg_annual_pay * 1000)
gen log_annual_avg_emplvl = ln(annual_avg_emplvl * 1000)
gen log_federal_funding = ln(federal_funding * 1000000)
recode log_* (. = 0)


//regressions for paper
reg log_federal_funding i.msa_factor, robust cluster(msa_factor)
predict resid_log_federal_funding, residuals
reg defense_funding_instrument i.msa_factor, robust cluster(msa_factor)
predict resid_defense_funding_instrument, residuals

reg resid_log_federal_funding resid_defense_funding_instrument, robust cluster(msa_factor)
outreg2 using output/defense_first_stage.doc, replace ctitle("With MSA FE") addstat("F stat", e(F))

ivregress 2sls log_avg_annual_pay i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/defense_iv.doc, replace ctitle("Average annual pay (log-log)") keep(log_federal_funding)
ivregress 2sls log_annual_avg_emplvl i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/defense_iv.doc, append ctitle("Average employment (log-log)") keep(log_federal_funding)



//make table for slides (note: not log-log)
reg avg_annual_pay federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/results_slides.doc, replace ctitle("OLS full controls, Average annual pay (thousands 2019$)") keep(federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

reg annual_avg_emplvl federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/results_slides.doc, append ctitle("OLS full controls, Average employment (thousands)") keep(federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

ivregress 2sls avg_annual_pay i.msa_factor (federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/results_slides.doc, append ctitle("IV defense instrument, Average annual pay (thousands 2019$)") keep(federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
ivregress 2sls annual_avg_emplvl i.msa_factor (federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/results_slides.doc, append ctitle("IV defense instrument, Average employment (thousands)") keep(federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)



//presidential vote instrument--------------

//process presidential voting data by county
import delimited data/raw/countypres_2000-2016.csv, clear

replace fips = "0" + fips if strlen(fips) == 4

ren county county_name
ren fips COUNTY

replace candidatevotes = "" if candidatevotes == "NA"
destring candidatevotes, replace

drop candidate
reshape wide candidatevotes, i(year state state_po county_name COUNTY) j(party) string

merge m:1 COUNTY using data/intermediate/county-to-msa
drop if _merge != 3
drop if msacode == ""
drop csa* _merge

collapse (sum) candidatevotes*, by(msacode msatitle year)
gen totalvotes = candidatevotesdem + candidatevotesrep + candidatevotesgreen + candidatevotesNA

gen votes_for_winner = .
replace votes_for_winner = candidatevotesrep if inlist(year, 2000, 2004, 2016)
replace votes_for_winner = candidatevotesdem if inlist(year, 2008, 2012)

gen voteshare_for_winner = votes_for_winner/totalvotes
gen max_votes_for_candidate = max(candidatevotesdem, candidatevotesrep)
gen voted_for_winner = votes_for_winner == max_votes_for_candidate
gen election_gap = abs((candidatevotesdem - candidatevotesrep)/totalvotes)

ren year election_year

save data/intermediate/msa_presidential_voting, replace



//attach instrument to panel
use data/intermediate/merged_MetroMSAs_allind_post01, clear

gen election_year = year - mod(year,4)
replace election_year = year - 4 if mod(year,4) == 0

merge m:1 msacode msatitle election_year using data/intermediate/msa_presidential_voting
keep if _merge == 3
encode msacode, gen(msa_factor)
drop _merge

//take logs
gen log_avg_annual_pay = ln(avg_annual_pay)
gen log_annual_avg_emplvl = ln(annual_avg_emplvl)
gen log_federal_funding = ln(federal_funding * 1000)
recode log_* (. = 0)

gen product_winner_gap = voted_for_winner * election_gap


//first stage
reg log_federal_funding voted_for_winner election_gap product_winner_gap, robust cluster(msa_factor)
outreg2 using output/pres_firststage.doc, replace ctitle("No MSA FE") addstat("F stat", e(F))

reg log_federal_funding i.msa_factor, robust cluster(msa_factor)
predict resid_log_federal_funding, residuals
reg voted_for_winner i.msa_factor, robust cluster(msa_factor)
predict resid_voted_for_winner, residuals
reg election_gap i.msa_factor, robust cluster(msa_factor)
predict resid_election_gap, residuals
reg product_winner_gap i.msa_factor, robust cluster(msa_factor)
predict resid_product_winner_gap, residuals

reg resid_log_federal_funding resid_voted_for_winner resid_election_gap resid_product_winner_gap, robust cluster(msa_factor)
outreg2 using output/pres_firststage.doc, append ctitle("With MSA FE") addstat("F stat", e(F))


//IV
ivregress 2sls log_avg_annual_pay (log_federal_funding = voted_for_winner resid_election_gap resid_product_winner_gap), robust cluster(msa_factor)
outreg2 using output/pres_iv_avg_annual_pay.doc, replace ctitle("No MSA FE") keep(log_federal_funding)
ivregress 2sls log_avg_annual_pay i.msa_factor (log_federal_funding = voted_for_winner resid_election_gap resid_product_winner_gap i.msa_factor), robust cluster(msa_factor)
outreg2 using output/pres_iv_avg_annual_pay.doc, append ctitle("With MSA FE") keep(log_federal_funding)

ivregress 2sls log_annual_avg_emplvl (log_federal_funding = voted_for_winner resid_election_gap resid_product_winner_gap), robust cluster(msa_factor)
outreg2 using output/pres_iv_annual_avg_emplvl.doc, replace ctitle("No MSA FE") keep(log_federal_funding)
ivregress 2sls log_annual_avg_emplvl i.msa_factor (log_federal_funding = voted_for_winner resid_election_gap resid_product_winner_gap i.msa_factor), robust cluster(msa_factor)
outreg2 using output/pres_iv_annual_avg_emplvl.doc, append ctitle("With MSA FE") keep(log_federal_funding)







