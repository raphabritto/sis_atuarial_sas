* -----------------------------------------------------*;
* --- tabua pensao Djx:x_M:F participante feminino --- *;
* -----------------------------------------------------*;

%let qtd_tabua_pensao = 0;

%macro calculaTabuaPensao;
	%let count = 0;

	%do tipo = 1 %to 4;
		%do t = 0 %to &numberOfTaxaJuros - 1;
			%do sexo_x = 1 %to 2;
				%_eg_conditional_dropds(work.tabua_pensao_djxx_temp);

				proc iml;
					if (&sexo_x = 1) then 
						sexo_j = 2;
					else
						sexo_j = 1;

					USE TABUAS.TABUAS_SERVICO_NORMAL;
						if (&tipo = 1) then do;
							read all var {t sexo idade lx} into tabua_x where (t = &t & sexo = &sexo_x);
							read all var {t sexo idade dxcb} into tabua_j where (t = &t & sexo = sexo_j);
						end;
						else if (&tipo = 2) then do;
							read all var {t sexo idade lxii} into tabua_x where (t = &t & sexo = &sexo_x);
							read all var {t sexo idade dxcb} into tabua_j where (t = &t & sexo = sexo_j);
						end;
						else if (&tipo = 3) then do;
							read all var {t sexo idade lx} into tabua_x where (t = &t & sexo = &sexo_x);
							read all var {t sexo idade dxiicb} into tabua_j where (t = &t & sexo = sexo_j);
						end;
						else if (&tipo = 4) then do;
							read all var {t sexo idade lxii} into tabua_x where (t = &t & sexo = &sexo_x);
							read all var {t sexo idade dxiicb} into tabua_j where (t = &t & sexo = sexo_j);
						end;
					CLOSE;

					qtdRows_x = nrow(tabua_x);
					qtdRows_j = nrow(tabua_j);
					tabua_pensao_temp = J((qtdRows_x * qtdRows_j), 6, 0);
					c = 1;

					do a = 1 to qtdRows_x;
						do b = 1 to qtdRows_j;
							tabua_pensao_temp[c, 1] = &t;
							tabua_pensao_temp[c, 2] = &tipo;
							tabua_pensao_temp[c, 3] = tabua_x[a, 2];
							tabua_pensao_temp[c, 4] = tabua_x[a, 3];
							tabua_pensao_temp[c, 5] = tabua_j[b, 3];
							tabua_pensao_temp[c, 6] = round(tabua_x[a, 4] * tabua_j[b, 4], &vRoundProb);
							c = c + 1;
						end;
					end;

					create work.tabua_pensao_djxx_temp from tabua_pensao_temp[colname={'t' 'tipo' 'sexo' 'idade_x' 'idade_j' 'djxx'}];
						append from tabua_pensao_temp;
					close;
				quit;

				%let count = %eval(&count+1);

				%_eg_conditional_dropds(work.tabua_pensao_djxx_&count);
				data work.tabua_pensao_djxx_&count;
					set work.tabua_pensao_djxx_temp;
					format djxx COMMAX30.3;
				run;

				%_eg_conditional_dropds(WORK.TRNS_TABUA_PENSAO_DJXX, WORK.SORTTempTableSorted);
				PROC SORT
					DATA=work.tabua_pensao_djxx_temp(KEEP=djxx t tipo sexo idade_j)
					OUT=WORK.SORTTempTableSorted;
					BY t tipo sexo idade_j;
				RUN;

				PROC TRANSPOSE DATA=WORK.SORTTempTableSorted
					OUT=WORK.TRNS_TABUA_PENSAO_DJXX(drop=t tipo sexo idade_j Source Label)
					NAME=Source
					LABEL=Label;
					BY t tipo sexo idade_j;
					VAR djxx;
				RUN; QUIT;
				%_eg_conditional_dropds(WORK.SORTTempTableSorted);

				%_eg_conditional_dropds(work.tabua_pensao_njxx_temp);
				proc iml;
					use WORK.TRNS_TABUA_PENSAO_DJXX;
						read all var _all_ into djxx;
					close;

					qtdRows = nrow(djxx);
					qtdCols = ncol(djxx);
					tabua_pensao_njxx = J(qtdRows * qtdCols, 6, 0);
					c = 1;
					iddMax = qtdRows - 1;

					do a = 0 to iddMax;
						do b = 0 to iddMax;
							d = a + 1;
							e = b + 1;
							soma = 0;

							do while (d <= qtdRows & e <= qtdCols);
								soma = soma + djxx[e, d];
								d = d + 1;
								e = e + 1;
							end;

							tabua_pensao_njxx[c, 1] = &t;
							tabua_pensao_njxx[c, 2] = &tipo;
							tabua_pensao_njxx[c, 3] = &sexo_x;
							tabua_pensao_njxx[c, 4] = a;
							tabua_pensao_njxx[c, 5] = b;
							tabua_pensao_njxx[c, 6] = round(soma, &vRoundProb);
							c = c + 1;
						end;
					end;

					create work.tabua_pensao_njxx_temp from tabua_pensao_njxx[colname={'t' 'tipo' 'sexo' 'idade_x' 'idade_j' 'njxx'}];
						append from tabua_pensao_njxx;
					close;

					free tabua_pensao_njxx djxx;
				quit;

				data work.TABUA_PENSAO_NJXX_&count;
					set WORK.tabua_pensao_njxx_temp;
					format njxx commax30.3;
				run; quit;
/*				%_eg_conditional_dropds(work.tabua_pensao_djxx_temp WORK.tabua_pensao_njxx_temp);*/
			%end;
		%end;
	%end;

/*	proc delete data = work.tabua_pensao_djxx_temp WORK.tabua_pensao_njxx_temp TRNS_TABUA_PENSAO_DJXX;*/

	data _null_;
		call symputx('qtd_tabua_pensao', &count);
	run; quit;
%mend;
%calculaTabuaPensao;


%_eg_conditional_dropds(tabuas.tabuas_pensao_djxx);
data tabuas.tabuas_pensao_djxx;
	set work.tabua_pensao_djxx_1 - work.tabua_pensao_djxx_&qtd_tabua_pensao;
run;

data tabuas.tabuas_pensao_njxx;
	set work.tabua_pensao_njxx_1 - work.tabua_pensao_njxx_&qtd_tabua_pensao;
run;

/*proc datasets nodetails library=work;*/
/*   delete tabua_pensao_djxx_1 - tabua_pensao_djxx_&qtd_tabua_pensao;*/
/*   delete tabua_pensao_njxx_1 - tabua_pensao_njxx_&qtd_tabua_pensao;*/
/*run;*/

proc datasets library=work kill memtype=data nolist;
	run;
quit;