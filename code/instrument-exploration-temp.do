cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

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

//keep year msa* voted_for_winner voteshare_for_winner election_gap

ren year election_year

save data/intermediate/msa_presidential_voting, replace



//try some regressions
//use data/intermediate/merged_allMSAs_allind_post01, clear
use data/intermediate/merged_MetroMSAs_allind_post01, clear

gen election_year = year - mod(year,4)
replace election_year = year - 4 if mod(year,4) == 0

merge m:1 msacode msatitle election_year using data/intermediate/msa_presidential_voting
keep if _merge == 3
encode msacode, gen(msa_factor)

replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000000 
label variable annual_avg_emplvl "Annual average of total employment (million)"
replace dataFederal = dataFederal / 1000000
label variable dataFederal "Total federal FFRDC funding received (millions 2019$)"

reg dataFederal voted_for_winner, robust
outreg2 using output/pres_firststage.doc, replace ctitle("Voted for winner")
//reg dataFederal voted_for_winner i.msa_factor
//outreg2 using output/pres_firststage.doc, append ctitle("Voted for winner")
reg dataFederal election_gap, robust,
outreg2 using output/pres_firststage.doc, append ctitle("Election gap")
//reg dataFederal election_gap i.msa_factor, robust,
//outreg2 using output/pres_firststage.doc, append ctitle("Election gap")


ivregress 2sls avg_annual_pay (dataFederal = voted_for_winner), robust
outreg2 using output/pres_iv_avg_annual_pay.doc, replace ctitle("Voted for winner") keep(dataFederal) addtext(MSA FE, No)
ivregress 2sls avg_annual_pay i.msa_factor (dataFederal = voted_for_winner), robust
outreg2 using output/pres_iv_avg_annual_pay.doc, append ctitle("Voted for winner") keep(dataFederal) addtext(MSA FE, Yes)
ivregress 2sls avg_annual_pay (dataFederal = election_gap), robust
outreg2 using output/pres_iv_avg_annual_pay.doc, append ctitle("Election gap") keep(dataFederal) addtext(MSA FE, No)
ivregress 2sls avg_annual_pay i.msa_factor (dataFederal = election_gap), robust
outreg2 using output/pres_iv_avg_annual_pay.doc, append ctitle("Election gap") keep(dataFederal) addtext(MSA FE, Yes)

ivregress 2sls annual_avg_emplvl (dataFederal = voted_for_winner), robust
outreg2 using output/pres_iv_annual_avg_emplvl.doc, replace ctitle("Voted for winner") keep(dataFederal) addtext(MSA FE, No)
ivregress 2sls annual_avg_emplvl i.msa_factor (dataFederal = voted_for_winner), robust
outreg2 using output/pres_iv_annual_avg_emplvl.doc, append ctitle("Voted for winner") keep(dataFederal) addtext(MSA FE, Yes)
ivregress 2sls annual_avg_emplvl (dataFederal = election_gap), robust
outreg2 using output/pres_iv_annual_avg_emplvl.doc, append ctitle("Election gap") keep(dataFederal) addtext(MSA FE, No)
ivregress 2sls annual_avg_emplvl i.msa_factor (dataFederal = election_gap), robust
outreg2 using output/pres_iv_annual_avg_emplvl.doc, append ctitle("Election gap") keep(dataFederal) addtext(MSA FE, Yes)


reg dataFederal election_gap i.election_year i.msa_factor