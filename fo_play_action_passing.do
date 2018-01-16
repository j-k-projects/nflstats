/* *******************
** Code for looking at the relationship between rushing and the effectiveness of play action passing
** Can't run without access to data but can view how variables were defined, data decisions, etc.
******************* */

clear
set mem 1g

cd "C:\Users\ben\Dropbox\nfl\fodata\"

//define a list of variables that are relevant for this to keep
global varlist play_action down togo yards year offydl offense pltype pline offense ///
defense offydl pressure description week home away gap recept pyd xtranote

/*
//a bunch of boring stuff reading and cleaning each season's data
*/
forvalues i = 2/5 {
di "`i'"
insheet using "201`i' Game Charting Pivot.csv", clear
	ren pa play_action
	capture ren fopressureyn pressureyn
	capture gen pressure = 1 if pressureyn==1
	capture gen pressure = 1 if pressureyn=="Yes"
	keep $varlist
	tempfile y`i'
	save `y`i'', replace
}

//2016
insheet using "2016 Charting Combined Pass-Run v3 for Ajit pressure.csv", clear
	ren pasis play_action
	capture ren fopressureyn pressureyn
	capture gen pressure = 1 if pressureyn==1
	capture gen pressure = 1 if pressureyn=="Yes"
	keep $varlist
	tempfile y6
	save `y6', replace
	
//2011
insheet using "2011 Game Charting Master v2.csv", clear
	drop if yards==.
	ren pa play_action
	gen pressure = 1 if passpressure!=""
	keep $varlist
	
	forvalues i = 2/6 {
	append using `y`i''
	}

//generate unique gameids based on home team, away team, year
egen gameid = group(home away year)
egen team_game = group(gameid offense)

so year week gameid pline

//pline with .5 means a play was challenged & line is a duplicate. remove the before challenge line
gen pline5 = 1 if mod(pline,1) > 0
drop if pline5[_n+1]==1

//label plays as from shotgun
gen shotgun = strpos(xtranote, "Shotgun")
replace shotgun = 1 if shotgun>0 & shotgun!=.
drop xtranote

//label plays as play action
gen pa = play_action == "PA" | play_action == "PA/EA"

//count scrambles as pass plays since they were intended as such
replace pltype = "pass" if recept == "scramble"
keep if pltype=="pass" | pltype == "rushed"
	gen rush = pltype == "rushed"
	gen pass = pltype == "pass"

//for success rate, use the basic FO definition of success (40% first down, 60% second down, 100% on remaining downs)
gen rush_success = 1 if rush == 1 & yards>=togo
replace rush_success = 1 if rush == 1 & yards>=.4*togo & down == 1
replace rush_success = 1 if rush == 1 & yards>=.6*togo & down == 2
replace rush_success = 0 if rush_success == .

//gen the number of offensive plays for each team
so year week gameid offense pline
gen playno = 1 if gameid!=gameid[_n-1] | offense!=offense[_n-1]
replace playno = playno[_n-1]+1 if playno == .

//total rush attempts for each team to that point in the game
gen totrush = rush if playno == 1
replace totrush = totrush[_n-1] + rush if offense == offense[_n-1] & gameid == gameid[_n-1]

//total pass attempts for each team to that point in the game
gen totpass = pass if playno == 1
replace totpass = totpass[_n-1] + pass if offense == offense[_n-1] & gameid == gameid[_n-1]

//total rush successes for each team to that point in the game
gen totsuccess = rush_success if playno == 1
replace totsuccess = totsuccess[_n-1] + rush_success if offense == offense[_n-1] & gameid== gameid[_n-1]

//rushing success ratio is successful rushes / total rushes
gen success_ratio = totsuccess[_n-1] / totrush[_n-1] if playno>5

//break success ratio into categories
gen group_success_ratio = 0 if success_ratio<=.4 & playno>=10
replace group_success_ratio = 1 if success_ratio>.4 & success_ratio<=.5 & playno>=10
replace group_success_ratio = 2 if success_ratio>.5 & success_ratio<=.6 & playno>=10
replace group_success_ratio = 3 if success_ratio>.6 & success_ratio<=1 & playno>=10

label def grouplbl2 0 "<40%"
label def grouplbl2 1 "40-50%", add
label def grouplbl2 2 "50-60%", add
label def grouplbl2 3 "60+%", add

label values group_success_ratio grouplbl2

//get ratio of rushes to total plays to that point in game
gen rush_ratio = totrush[_n-1]/(totpass[_n-1]+ totrush[_n-1]) if playno>5
egen cut_rush_ratio = cut(rush_ratio), group(5)

//break rush ratio into categories
gen group_rush_ratio = 0 if rush_ratio<=.3 & playno>=10
replace group_rush_ratio = 1 if rush_ratio>.3 & rush_ratio<=.4 & playno>=10
replace group_rush_ratio = 2 if rush_ratio>.4 & rush_ratio<=.5 & playno>=10
replace group_rush_ratio = 3 if rush_ratio>.5 & rush_ratio<=1 & playno>=10

label def grouplbl 0 "<30%"
label def grouplbl 1 "30-40%", add
label def grouplbl 2 "40-50%", add
label def grouplbl 3 "50+%", add

label values group_rush_ratio grouplbl

tsset team_game playno

//get number of rushes and successful rushes in previous 5/10 plays
gen rush_last5 = l.rush+l2.rush+l3.rush+l4.rush+l5.rush if playno>5
gen rush_last10 = l.rush+l2.rush+l3.rush+l4.rush+l5.rush+l6.rush+l7.rush+l8.rush+l9.rush+l10.rush if playno>10

gen rush_success_last5 = l.rush_success+l2.rush_success+l3.rush_success+l4.rush_success+l5.rush_success if playno>5
gen rush_success_last10 = l.rush_success+l2.rush_success+l3.rush_success+l4.rush_success+l5.rush_success+l6.rush_success+l7.rush_success+l8.rush_success+l9.rush_success+l10.rush_success if playno>10

replace pressure = 0 if pressure == .

//final cleaned dataset
save fo_2011_2016, replace

/*

SEASON-LEVEL SCATTERPLOTS

*/

clear matrix
clear
set mem 1g
use "C:\Users\ben\Dropbox\nfl\fodata\fo_2011_2016", clear

preserve
	//keep if gap>=-7 & gap<=7    /* for testing score within 7 points */
	collapse (sum) rush pass rush_success, by(offense year)
	tempfile team
	save `team', replace
restore

keep if pa == 1 & rush == 0
collapse (mean) yards, by(offense year)

merge 1:1 offense year using `team'

gen success_rate = rush_success/rush
gen rush_rate = rush / (rush + pass)
gen syear = year - 2000
tostring syear, replace
gen tm = offense+syear //for labeling some test graphs, not used in piece

//basic season-long rush freq vs PA yards w label
twoway scatter yards rush_rate, mlabel(tm) graphregion(fcolor(white))

//basic season-long rush freq vs PA yards w label, west divisions
twoway scatter yards rush_rate if offense=="SEA" | offense=="SF" | offense=="STL" | offense=="LARM" | offense=="ARI", mlabel(tm) graphregion(fcolor(white))
twoway scatter yards rush_rate if offense=="SD" | offense=="DEN" | offense=="KC" | offense=="OAK", mlabel(tm) graphregion(fcolor(white))

//make the graphs used in the piece
qui reg yards rush_rate //.48 for all, .52 for close game
local r2 = string(`e(r2)',"%9.2f")
twoway scatter yards rush_rate, graphregion(fcolor(white)) text(5 .48 "R2 = `r2'") ytitle(Yards per play) xtitle(Proportion rushes) ///
name(rate, replace) title(Rush ratio)

qui reg yards rush //525 for all, 375 for close game
local r2 = string(`e(r2)',"%9.2f")
twoway scatter yards rush, graphregion(fcolor(white)) text(5 525 "R2 = `r2'") ytitle(Yards per play) xtitle(Total rushes) ///
name(total, replace) title(Rushes)

qui reg yards success_rate
local r2 = string(`e(r2)',"%9.2f")
twoway scatter yards success_rate, graphregion(fcolor(white)) text(5 .55 "R2 = `r2'") ytitle(Yards per play) xtitle(Rushing success rate) ///
name(success, replace) title(Rush success rate)

window manage close graph _all

//season-level results: graph in piece
graph combine total rate success, cols(2) title(Play action passing vs measures of rushing) ///
graphregion(fcolor(white)) ///
t1title("NFL, 2011-2016")

*t1title("NFL, 2011-2016")
*t1title("NFL, 2011-2016, rushing within 7 points")

graph export results/season_all.png, replace
*graph export results/season_close.png, replace



/*

PLAY-LEVEL RESULTS

*/

clear matrix
clear
set mem 1g
cd "C:\Users\ben\Dropbox\nfl\fodata\"
use "C:\Users\ben\Dropbox\nfl\fodata\fo_2011_2016", clear

keep if pa == 1 & rush == 0

//drop a few extreme cases with small sample size to make graphs look better
replace rush_last10 = . if rush_last10 >= 9 //about 0.4% of sample

replace rush_success_last5 = . if rush_success_last5 == 5 //only 32 obs for 5 (0.14% of sample)
replace rush_success_last10 = . if rush_success_last10>=7 //.31% of sample

//make a bunch of graphs for all the different definitions of rushing
foreach var in rush_success_last5 rush_success_last10 rush_last5 rush_last10 group_rush_ratio group_success_ratio {

if "`var'" == "rush_success_last5" {
	local title "Rush success in prev 5"
	local xtitle "Successes"
	local xlab "xlabel(0 1 2 3 4)"
	}
	
if "`var'" == "rush_last5" {
	local title "Rushes in prev 5 plays"
	local xtitle "Rushes"
	local xlab "xlabel(0 1 2 3 4 5)"
	}
	
if "`var'" == "rush_success_last10" {
	local title "Rush success in prev 10"
	local xtitle "Successes"
	local xlab "xlabel(0 1 2 3 4 5 6)"
	}
	
if "`var'" == "rush_last10" {
	local title "Rush in prev 10"
	local xtitle "Rushes"
	local xlab "xlabel(0 1 2 3 4 5 6 7 8)"
	}
	
if "`var'" == "group_rush_ratio" {
	local title "Rush ratio"
	local xtitle "Ratio"
	local xlab "xlabel(0 1 2 3, valuelabel)"
	}
	
if "`var'" == "group_success_ratio" {
	local title "Rush success rate"
	local xtitle "Rate"
	local xlab "xlabel(0 1 2 3, valuelabel)"
	}
	
so `var'

by `var': egen med = median(yards)
by `var': egen uqt = pctile(yards), p(75)
by `var': egen mean = mean(yards)

by `var': egen mean_p = mean(pressure)
by `var': egen mean_s = mean(shotgun)

by `var': egen med_a = median(pyd)
by `var': egen uqt_a = pctile(pyd), p(75)
by `var': egen mean_a = mean(pyd)


twoway ///
       rbar med uqt `var', fcolor(gs12) lcolor(black) barw(.5) || ///
       scatter mean `var', msymbol(Oh) msize(*2) fcolor(gs12) mcolor(black) ///
       ytitle("") xtitle("") title(`title') `xlab' ///
	   graphregion(fcolor(white)) name(`var', replace) ///
	   legend(label(1 "Median to 75th pctile range") label(2 "Average")) nodraw
	   *graph export results/yards_`var'.png, replace

twoway scatter mean_p `var', msymbol(Oh) msize(*2) fcolor(gs12) mcolor(black) ytitle("") ///
	xtitle("") title(`title') `xlab' ///
	graphregion(fcolor(white)) name(`var'p, replace) ///
	legend(off) nodraw
	*graph export results/pressure_`var'.png, replace
	
twoway scatter mean_s `var', msymbol(Oh) msize(*2) fcolor(gs12) mcolor(black) ytitle("") ///
	xtitle("") title(`title') `xlab' ///
	graphregion(fcolor(white)) name(`var's, replace) ///
	legend(off) nodraw
	*graph export results/shotgun_`var'.png, replace
	   
twoway ///
       rbar med_a uqt_a `var', fcolor(gs12) lcolor(black) barw(.5) || ///
       scatter mean_a `var', msymbol(Oh) msize(*2) fcolor(gs12) mcolor(black) ///
       ytitle("") xtitle("") title(`title') `xlab' ///
	   graphregion(fcolor(white)) name(`var'a, replace) ///
	   legend(label(1 "Median to 75th pctile range") label(2 "Average")) nodraw
	   *graph export results/air_`var'.png, replace
	   
   
if "`var'" == "group_rush_ratio" {
	local xlab "xlabel(0 "<30" 1 "30-40" 2 "40-50" 3 "50+")"
	}
	
if "`var'" == "group_success_ratio" {
	local xlab "xlabel(0 "<40" 1 "40-50" 2 "50-60" 3 "60+")"
	}
	
hist `var', freq discrete yla(, format(%5.0f) ang(h)) graphregion(fcolor(white)) fcolor(gs12) mcolor(black) ///
	ytitle("") xtitle("") title(`title') `xlab' name(`var'h, replace) nodraw
	   
drop med uqt mean mean_p mean_a uqt_a med_a mean_s
window manage close graph _all

}


/* ********
get likelihood of actually passing given showing handoff
********* */

clear matrix
clear
set mem 1g
cd "C:\Users\ben\Dropbox\nfl\fodata\"
use "C:\Users\ben\Dropbox\nfl\fodata\fo_2011_2016", clear


keep if pa == 1 | rush == 1

replace rush_last10 = . if rush_last10 >= 9 //about 0.4% of sample

replace rush_success_last5 = . if rush_success_last5 == 5 //only 32 obs for 5 (0.14% of sample)
replace rush_success_last10 = . if rush_success_last10>=7 //.31% of sample

foreach var in rush_success_last5 rush_success_last10 rush_last5 rush_last10 group_rush_ratio group_success_ratio {

if "`var'" == "rush_success_last5" {
	local title "Rush success in prev 5"
	local xtitle "Successes"
	local xlab "xlabel(0 1 2 3 4)"
	}
	
if "`var'" == "rush_last5" {
	local title "Rushes in prev 5 plays"
	local xtitle "Rushes"
	local xlab "xlabel(0 1 2 3 4 5)"
	}
	
if "`var'" == "rush_success_last10" {
	local title "Rush success in prev 10"
	local xtitle "Successes"
	local xlab "xlabel(0 1 2 3 4 5 6)"
	}
	
if "`var'" == "rush_last10" {
	local title "Rush in prev 10"
	local xtitle "Rushes"
	local xlab "xlabel(0 1 2 3 4 5 6 7 8)"
	}
	
if "`var'" == "group_rush_ratio" {
	local title "Rush ratio"
	local xtitle "Ratio"
	local xlab "xlabel(0 1 2 3, valuelabel)"
	}
	
if "`var'" == "group_success_ratio" {
	local title "Rush success rate"
	local xtitle "Rate"
	local xlab "xlabel(0 1 2 3, valuelabel)"
	}
	
so `var'
* Use egen to generate the median, quartiles, interquartile range (IQR), and mean.

by `var': egen mean_p = mean(pa)

twoway scatter mean_p `var', msymbol(Oh) msize(*2) fcolor(gs12) mcolor(black) ytitle("") ///
	xtitle("") title(`title') `xlab' ///
	graphregion(fcolor(white)) name(`var'pa, replace) ///
	legend(off) nodraw
	*graph export results/pa_`var'.png, replace
	
	drop mean_p
	
window manage close graph _all

}


//the graphs that appear in the piece
graph combine rush_last5h rush_success_last5h rush_last10h rush_success_last10h group_rush_ratioh group_success_ratioh, ycommon ///
title("Frequency of various rushing measures") graphregion(fcolor(white)) name(combined_h, replace) l1(Frequency)
graph export results/combined_h.png, replace

graph combine rush_last5pa rush_success_last5pa rush_last10pa rush_success_last10pa group_rush_ratiopa group_success_ratiopa, ycommon ///
title("Likelihood of passing given showing handoff") graphregion(fcolor(white)) name(combined_pa, replace) l1(Pass likelihood)
graph export results/combined_pa.png, replace

graph combine rush_last5p rush_success_last5p rush_last10p rush_success_last10p group_rush_ratiop group_success_ratiop, ycommon ///
title("Pressure rate on PA dropbacks") graphregion(fcolor(white)) name(combined_p, replace) l1(Pressure rate)
graph export results/combined_p.png, replace

graph combine rush_last5s rush_success_last5s rush_last10s rush_success_last10s group_rush_ratios group_success_ratios, ycommon ///
title("Shotgun rate on PA dropbacks") graphregion(fcolor(white)) name(combined_s, replace) l1(Shotgun rate)
graph export results/combined_s.png, replace

grc1leg rush_last5a rush_success_last5a rush_last10a rush_success_last10a group_rush_ratioa group_success_ratioa, ycommon ///
title("Depth of target on PA dropbacks") graphregion(fcolor(white)) name(combined_a, replace) l1(Depth of target)
graph export results/combined_a.png, replace

grc1leg rush_last5 rush_success_last5 rush_last10 rush_success_last10 group_rush_ratio group_success_ratio, ycommon ///
title("Yards per PA dropback") graphregion(fcolor(white)) name(combined, replace) l1(Yards per dropback)
graph export results/combined.png, replace

window manage close graph _all
