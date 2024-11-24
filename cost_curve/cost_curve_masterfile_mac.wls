#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Assign parameters*) 
Clear[X,s,x, K, K2];
(* Identify K and a   *) 
args = Rest @ $ScriptCommandLine;

price  =ToExpression[Part[args,1]]
fcr =ToExpression[Part[args,2]]
\[Epsilon]=ToExpression[Part[args,3]]
\[Theta]=ToExpression[Part[args,4]]
X0 = ToExpression[Part[args,5]]
\[Rho] = ToExpression[Part[args,6]]
x0 = ToExpression[Part[args,7]]
tmax =ToExpression[Part[args,8]]
enviro\[LetterSpace]cons\[LetterSpace]early =ToExpression[Part[args,9]]
enviro\[LetterSpace]cons\[LetterSpace]late =ToExpression[Part[args,10]]
enviro\[LetterSpace]slope\[LetterSpace]early =ToExpression[Part[args,11]]
enviro\[LetterSpace]slope\[LetterSpace]late =ToExpression[Part[args,12]]
enviro\[LetterSpace]extra =ToExpression[Part[args,13]]
enviro\[LetterSpace]end =ToExpression[Part[args,14]]
enviro\[LetterSpace]cap =ToExpression[Part[args,15]]
baseline\[LetterSpace]subsidy =ToExpression[Part[args,16]]
subsidy\[LetterSpace]end =ToExpression[Part[args,17]]
\[Mu]=ToExpression[Part[args,18]]
\[Gamma]=ToExpression[Part[args,19]]
graph=ToExpression[Part[args,20]]
start\[LetterSpace]year\[LetterSpace]offset=ToExpression[Part[args,21]]
cutoff =ToExpression[Part[args,22]]
graphfilename = Part[args,23]
filename = Part[args,24]
rdirect = If[fcr!=0, 1/((1/fcr)-1),0]



cost = (price-\[Gamma]*baseline\[LetterSpace]subsidy)/(\[Mu]+1);
\[Kappa]=cost/((1+rdirect)*X0^\[Theta])
K = (cost*rdirect)/(1+rdirect)

(* Make the subsidy function and its derivative*)
tau[t_]:= baseline\[LetterSpace]subsidy*(.5 + ArcTan[1000000*(t-subsidy\[LetterSpace]end)]/(-\[Pi]));
tauprime[t_]:= tau'[t];
(* Make the enviro  function*)
If[enviro\[LetterSpace]extra==0,
enviroext[t_]:= Boole[t+start\[LetterSpace]year\[LetterSpace]offset <cutoff ]*(enviro\[LetterSpace]cons\[LetterSpace]early +  enviro\[LetterSpace]slope\[LetterSpace]early*Log[t+start\[LetterSpace]year\[LetterSpace]offset])  + Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=cutoff]*(enviro\[LetterSpace]cons\[LetterSpace]late + enviro\[LetterSpace]slope\[LetterSpace]late*Log[t+start\[LetterSpace]year\[LetterSpace]offset]), 
enviroext[t_]:= Boole[t+start\[LetterSpace]year\[LetterSpace]offset <cutoff ]*(enviro\[LetterSpace]cons\[LetterSpace]early +  enviro\[LetterSpace]slope\[LetterSpace]early*(t+start\[LetterSpace]year\[LetterSpace]offset)+enviro\[LetterSpace]extra*(t+start\[LetterSpace]year\[LetterSpace]offset)^2)  + Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=cutoff]*Boole[t+start\[LetterSpace]year\[LetterSpace]offset <enviro\[LetterSpace]end ]*(enviro\[LetterSpace]cons\[LetterSpace]late + enviro\[LetterSpace]slope\[LetterSpace]late*(t+start\[LetterSpace]year\[LetterSpace]offset))+enviro\[LetterSpace]cap*Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=enviro\[LetterSpace]end ]]

s=NDSolve[{SetPrecision[X''[t]/X'[t]==\[Epsilon]*((\[Mu]+1)*\[Theta]*\[Kappa]*X[t]^(\[Theta]-1)*X'[t]+\[Rho]*tauprime[t])/((\[Mu]+1)*(K+\[Kappa]*X[t]^\[Theta])+\[Rho]*tau[t]),1000],X[0]==X0,X'[0]==x0},X[t],{t,0,tmax},AccuracyGoal->90,PrecisionGoal->Infinity,WorkingPrecision->100,Method->StiffnessSwitching,NormFunction->Infinity]; 



Xnum[t_]:= Evaluate[X[t]/.s[[1]]];
xnum[t_]:= Evaluate[Xnum'[t]];
xprimenum[t_]:= Evaluate[Xnum''[t]];
DP=(-\[Gamma]*\[Epsilon])/(x0*price)*NIntegrate[\[Theta]*\[Kappa]*(\[Mu]+1)*xnum[t]^2*Xnum[t]^(\[Theta]-1)*Exp[-\[Rho]*t],{t,0,tmax}]
D\[Pi]= -\[Mu]/(\[Mu]+1)*DP +(-\[Gamma]*\[Mu]*\[Epsilon])/(x0*price)*NIntegrate[Exp[-\[Rho]*t]*xprimenum[t]*(K+\[Kappa]*Xnum[t]^\[Theta]),{t,0,tmax}]
DE = (\[Gamma]*\[Epsilon])/(x0*price)*NIntegrate[Exp[-\[Rho]*t]*xprimenum[t]*(enviroext[t]),{t,0,tmax}]
DFE = (\[Gamma]*\[Epsilon])/(x0*price)*NIntegrate[Exp[-\[Rho]*t]*xprimenum[t]*(tau[t]),{t,0,tmax}]
If[graph==1,
g = Plot[(Xnum[t]),{t,0,50},PlotLabel->"X(t)"];
Export[StringJoin[graphfilename,"_X.png"],g];
g = Plot[(xnum[t]),{t,0,50},PlotLabel->"x(t)"];
Export[StringJoin[graphfilename,"_x.png"],g];

g = Plot[(xprimenum[t]),{t,0,50},PlotLabel->"x'(t)"];
Export[StringJoin[graphfilename,"_xprime.png"],g];

g = Plot[(enviroext[t]),{t,0,50},PlotLabel->"enviroext(t)"];
Export[StringJoin[graphfilename,"_enviroext.png"],g];

plotlab=StringJoin["DP=",ToString[DP]];
g=Plot[(-\[Gamma]*\[Epsilon])/(x0*price)*\[Theta]*\[Kappa]*(\[Mu]+1)*xnum[t]^2*Xnum[t]^(\[Theta]-1)*Exp[-\[Rho]*t],{t,0,50},PlotLabel->plotlab,Filling->Axis];
Export[StringJoin[graphfilename,"_DP.png"],g]

plotlab=StringJoin["DE=",ToString[DE]];
g=Plot[ (-\[Gamma]*\[Epsilon])/(x0*price)*Exp[-\[Rho]*t]*xprimenum[t]*(enviroext[t]),{t,0,50},PlotLabel->plotlab,Filling->Axis];;
Export[StringJoin[graphfilename,"_DE.png"],g];

plotlab=StringJoin["D\[Pi]=",ToString[D\[Pi]]];
g=Plot[(-\[Gamma]*\[Epsilon])/(x0*price)*Exp[-\[Rho]*t]*(-\[Mu]*\[Theta]*\[Kappa]**xnum[t]^2*Xnum[t]^(\[Theta]-1)+xprimenum[t]*(K+\[Kappa]*Xnum[t]^\[Theta])),{t,0,50},PlotLabel->plotlab,Filling->Axis];
Export[StringJoin[graphfilename,"_Dpi.png"],g];

plotlab=StringJoin["DFE=",ToString[DFE]];
g=Plot[(-\[Gamma]*\[Epsilon])/(x0*price)*Exp[-\[Rho]*t]*xprimenum[t]*(tau[t]),{t,0,50},PlotLabel->plotlab,Filling->Axis];
Export[StringJoin[graphfilename,"_DFE.png"],g], 
0]



output = FileNameJoin[{Directory[],filename}];
output=StringJoin[output,".csv"]
arrayout = {DP,D\[Pi],DE,DFE};
Export[output, arrayout]; 

