#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Assign parameters*) 
Clear[X,s,x, K, K2];
(* Identify K and a   *) 
args = Rest @ $ScriptCommandLine; 
args = args[[1]];
args = StringJoin["\"", args, "\""]

price  =ToExpression[StringExtract[args,2]]
\[Epsilon]=ToExpression[StringExtract[args,3]]
\[Theta]=ToExpression[StringExtract[args,4]]
X0 = ToExpression[StringExtract[args,5]]
\[Rho] = ToExpression[StringExtract[args,6]]
x0 = ToExpression[StringExtract[args,7]]
enviro\[LetterSpace]cons\[LetterSpace]early =ToExpression[StringExtract[args,8]]
enviro\[LetterSpace]cons\[LetterSpace]late =ToExpression[StringExtract[args,9]]
enviro\[LetterSpace]slope\[LetterSpace]early =ToExpression[StringExtract[args,10]]
enviro\[LetterSpace]slope\[LetterSpace]late =ToExpression[StringExtract[args,11]]
enviro\[LetterSpace]extra =ToExpression[StringExtract[args,12]]
enviro\[LetterSpace]end =ToExpression[StringExtract[args,13]]
enviro\[LetterSpace]cap =ToExpression[StringExtract[args,14]]
baseline\[LetterSpace]subsidy =ToExpression[StringExtract[args,15]]
\[Mu]=ToExpression[StringExtract[args,16]]
\[Gamma]=ToExpression[StringExtract[args,17]]
graph=ToExpression[StringExtract[args,18]]
tmax =ToExpression[StringExtract[args,19]] 
start\[LetterSpace]year\[LetterSpace]offset =ToExpression[StringExtract[args,20]]
cutoff = ToExpression[StringExtract[args,21]]
graphfilename = StringExtract[args,22]
filename = StringReplace[StringExtract[args,23],"\""->""]
rdirect = If[fcr!=0, 1/((1/fcr)-1),0]
cost = (price-\[Gamma]*baseline\[LetterSpace]subsidy)/(\[Mu]+1);
(*Identify the constants*) 
C2= X0/(x0*(1-\[Epsilon]*\[Theta]));
C1 = X0/C2^(1/(1-\[Epsilon]*\[Theta]));

(* Make the enviro  function*)
If[enviro\[LetterSpace]extra==0,
enviroext[t_]:= Boole[t+start\[LetterSpace]year\[LetterSpace]offset <cutoff ]*(enviro\[LetterSpace]cons\[LetterSpace]early +  enviro\[LetterSpace]slope\[LetterSpace]early*Log[t+start\[LetterSpace]year\[LetterSpace]offset])  + Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=cutoff]*(enviro\[LetterSpace]cons\[LetterSpace]late + enviro\[LetterSpace]slope\[LetterSpace]late*Log[t+start\[LetterSpace]year\[LetterSpace]offset]), 
enviroext[t_]:= Boole[t+start\[LetterSpace]year\[LetterSpace]offset <cutoff ]*(enviro\[LetterSpace]cons\[LetterSpace]early +  enviro\[LetterSpace]slope\[LetterSpace]early*(t+start\[LetterSpace]year\[LetterSpace]offset)+enviro\[LetterSpace]extra*(t+start\[LetterSpace]year\[LetterSpace]offset)^2)  + Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=cutoff]*Boole[t+start\[LetterSpace]year\[LetterSpace]offset <enviro\[LetterSpace]end ]*(enviro\[LetterSpace]cons\[LetterSpace]late + enviro\[LetterSpace]slope\[LetterSpace]late*(t+start\[LetterSpace]year\[LetterSpace]offset))+enviro\[LetterSpace]cap*Boole[t+start\[LetterSpace]year\[LetterSpace]offset>=enviro\[LetterSpace]end ]]
X[t_]:= C1*(t+C2)^(1/(1-\[Epsilon]*\[Theta]))
x[t_]:= C1*1/(1-\[Epsilon]*\[Theta])*(t+C2)^((\[Epsilon]*\[Theta])/(1-\[Epsilon]*\[Theta]))
xprime[t_]:= C1*(\[Epsilon]*\[Theta])/((1-\[Epsilon]*\[Theta])^2)*(t+C2)^((2*\[Epsilon]*\[Theta]-1)/(1-\[Epsilon]*\[Theta]))

DP=((-\[Gamma]*\[Epsilon])/(x0*X0^\[Theta]))* Integrate[\[Theta]*(\[Mu]+1)*x[t]^2*X[t]^(\[Theta]-1)*Exp[-\[Rho]*t],{t,0,\[Infinity]}];
D\[Pi]= (-\[Mu]/(\[Mu]+1))*DP +((-\[Gamma]*\[Mu]*\[Epsilon])/(x0*X0^\[Theta]))*Integrate[Exp[-\[Rho]*t]*xprime[t]*(X[t]^\[Theta]),{t,0,\[Infinity]}];
DE = (\[Gamma]*\[Epsilon])/(x0*price)*NIntegrate[Exp[-\[Rho]*t]*xprime[t]*(enviroext[t]),{t,0,tmax}];
If[graph==1,
g = Plot[(X[t]),{t,0,50},PlotLabel->"X(t)"];
Export[StringJoin[graphfilename,"_X.png"],g];

g = Plot[(x[t]),{t,0,50},PlotLabel->"x(t)"];
Export[StringJoin[graphfilename,"_x.png"],g];

g = Plot[(xprime[t]),{t,0,50},PlotLabel->"x'(t)"];
Export[StringJoin[graphfilename,"_xprime.png"],g];


g = Plot[(enviroext[t]),{t,0,50},PlotLabel->"enviroext(t)"];
Export[StringJoin[graphfilename,"_enviroext.png"],g];


plotlab=StringJoin["DP=",ToString[DP]];
g=Plot[(-\[Gamma]*\[Epsilon])/(x0*X0^\[Theta])*\[Theta]*(\[Mu]+1)*x[t]^2*X[t]^(\[Theta]-1)*Exp[-\[Rho]*t],{t,0,50},PlotLabel->plotlab,Filling->Axis];

Export[StringJoin[graphfilename,"_DP.png"],g]


plotlab=StringJoin["D\[Pi]=",ToString[D\[Pi]]];
g=Plot[(-\[Gamma]*\[Epsilon])/(x0*X0^\[Theta])*Exp[-\[Rho]*t]*(-\[Mu]*\[Theta]*x[t]^2*X[t]^(\[Theta]-1)+xprime[t]*(X[t]^\[Theta])),{t,0,50},PlotLabel->plotlab,Filling->Axis];
Export[StringJoin[graphfilename,"_Dpi.png"],g],
0]

output = FileNameJoin[{Directory[],filename}];
output=StringJoin[output,".csv"]
arrayout = {DP,D\[Pi],DE};
Export[output, arrayout];
