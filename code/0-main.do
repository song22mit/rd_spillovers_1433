
clear all
set more off
cap log close

cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

capture log using edwin_song_1433_main_log, replace

do code/1-clean-main-data.do
do code/2-summary-stats-and-ols.do
do code/3-instrument-processing-and-iv.do
do code/4-clean-industry-data.do
do code/5-industry-regressions.do


log close
translate edwin_song_1433_main_log.smcl edwin_song_1433_main_log.pdf