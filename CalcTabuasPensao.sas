* -----------------------------------------------------*;
* --- tabua pensao Djx:x_M:F participante feminino --- *;
* -----------------------------------------------------*;

/*proc iml;
	START CalcularTabuaServico(tabua_x, tabua_j, tipo_tabua);

		qtdRows_x = nrow(tabua_x);
		qtdRows_j = nrow(tabua_j);
		tabua_pensao_temp = J((qtdRows_x * qtdRows_j), 6, 0);
		c = 1;

		do a = 1 to qtdRows_x;
			do b = 1 to qtdRows_j;
				tabua_pensao_temp[c, 1] = tabua_x[a, 1];
				tabua_pensao_temp[c, 2] = tipo_tabua;
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
	finish;
	store module=CalcularTabuaServico;
quit;*/

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

					*load module=CalcularTabuaServico;
					*run CalcularTabuaServico(tabua_x, tabua_j, &tipo);

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

				*%_eg_conditional_dropds(work.tabuas_pensao_djxx_tipo&tipo._t&t.s&sexo_x.);
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
				%_eg_conditional_dropds(work.tabua_pensao_djxx_temp WORK.tabua_pensao_njxx_temp);

			%end;
		%end;
	%end;

	proc delete data = work.tabua_pensao_djxx_temp WORK.tabua_pensao_njxx_temp TRNS_TABUA_PENSAO_DJXX;

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

proc datasets nodetails library=work;
   delete tabua_pensao_djxx_1 - tabua_pensao_djxx_&qtd_tabua_pensao;
   delete tabua_pensao_njxx_1 - tabua_pensao_njxx_&qtd_tabua_pensao;
run;


* ------------------------------------------------------*;
* --- tabua pensao Djx:x_F:M participante masculino --- *;
* ------------------------------------------------------*;
/*%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_mas1);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL7} into dx where (COL2 = 2);
		read all var {COL2 COL1 COL23} into djx where (COL2 = 1);
	CLOSE;

	qtdRows_dx = nrow(dx);
	qtdRows_djx = nrow(djx);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 1;
			tabua_pensao_temp[c, 2] = dx[a, 1];
			tabua_pensao_temp[c, 3] = dx[a, 2];
			tabua_pensao_temp[c, 4] = djx[b, 2];
			tabua_pensao_temp[c, 5] = round(djx[b, 3] * dx[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_mas1 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_MAS1, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_MAS1(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_MAS1
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_MAS1
	drop column col1, col2, col4, Source;
run;

* ------------------------------------------------------------------*;
* --- tabua pensao Djx:x_M:F_i participante feminino e invalido --- *;
* ------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_fem2);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL17} into dx_i where (COL2 = 1);
		read all var {COL2 COL1 COL23} into djx where (COL2 = 2);
	CLOSE;

	qtdRows_dx = nrow(dx_i);
	qtdRows_djx = nrow(djx);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 2;
			tabua_pensao_temp[c, 2] = dx_i[a, 1];
			tabua_pensao_temp[c, 3] = dx_i[a, 2];
			tabua_pensao_temp[c, 4] = djx[b, 2];
			tabua_pensao_temp[c, 5] = round(djx[b, 3] * dx_i[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_fem2 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_FEM2, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_FEM2(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_FEM2
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_FEM2
	drop column col1, col2, col4, Source;
run;

* -------------------------------------------------------------------*;
* --- tabua pensao Djx:x_F:M_i participante masculino e invalido --- *;
* -------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_mas2);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL17} into dx_i where (COL2 = 2);
		read all var {COL2 COL1 COL23} into djx where (COL2 = 1);
	CLOSE TABUAS.TABUA_SERVICO_NORMAL_TEMP;

	qtdRows_dx = nrow(dx_i);
	qtdRows_djx = nrow(djx);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 2;
			tabua_pensao_temp[c, 2] = dx_i[a, 1];
			tabua_pensao_temp[c, 3] = dx_i[a, 2];
			tabua_pensao_temp[c, 4] = djx[b, 2];
			tabua_pensao_temp[c, 5] = round(djx[b, 3] * dx_i[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_mas2 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_MAS2, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_MAS2(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_MAS2
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_MAS2
	drop column col1, col2, col4, Source;
run;

* --------------------------------------------------------------------------*;
* --- tabua pensao Djx:x_M:Fi_ participante feminino e conjuge invalido --- *;
* --------------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_fem3);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL7} into dx where (COL2 = 1);
		read all var {COL2 COL1 COL29} into djx_i where (COL2 = 2);
	CLOSE TABUAS.TABUA_SERVICO_NORMAL_TEMP;

	qtdRows_dx = nrow(dx);
	qtdRows_djx = nrow(djx_i);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 3;
			tabua_pensao_temp[c, 2] = dx[a, 1];
			tabua_pensao_temp[c, 3] = dx[a, 2];
			tabua_pensao_temp[c, 4] = djx_i[b, 2];
			tabua_pensao_temp[c, 5] = round(djx_i[b, 3] * dx[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_fem3 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_FEM3, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_FEM3(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_FEM3
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_FEM3
	drop column col1, col2, col4, Source;
run;

* ---------------------------------------------------------------------------*;
* --- tabua pensao Djx:x_F:Mi_ participante masculino e conjuge invalido --- *;
* ---------------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_mas3);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL7} into dx where (COL2 = 2);
		read all var {COL2 COL1 COL29} into djx_i where (COL2 = 1);
	CLOSE TABUAS.TABUA_SERVICO_NORMAL_TEMP;

	qtdRows_dx = nrow(dx);
	qtdRows_djx = nrow(djx_i);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 3;
			tabua_pensao_temp[c, 2] = dx[a, 1];
			tabua_pensao_temp[c, 3] = dx[a, 2];
			tabua_pensao_temp[c, 4] = djx_i[b, 2];
			tabua_pensao_temp[c, 5] = round(djx_i[b, 3] * dx[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_mas3 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_MAS3, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_MAS3(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_MAS3
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_MAS3
	drop column col1, col2, col4, Source;
run;

* -----------------------------------------------------------------------------------*;
* --- tabua pensao Djx:x_M:Fii participante feminino invalido e conjuge invalido --- *;
* -----------------------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_fem4);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL17} into dx_i where (COL2 = 1);
		read all var {COL2 COL1 COL29} into djx_i where (COL2 = 2);
	CLOSE;

	qtdRows_dx = nrow(dx_i);
	qtdRows_djx = nrow(djx_i);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 4;
			tabua_pensao_temp[c, 2] = dx_i[a, 1];
			tabua_pensao_temp[c, 3] = dx_i[a, 2];
			tabua_pensao_temp[c, 4] = djx_i[b, 2];
			tabua_pensao_temp[c, 5] = round(djx_i[b, 3] * dx_i[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_fem4 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_FEM4, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_FEM4(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_FEM4
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_FEM4
	drop column col1, col2, col4, Source;
run;

* ------------------------------------------------------------------------------------*;
* --- tabua pensao Djx:x_F:Mii participante masculino invalido e conjuge invalido --- *;
* ------------------------------------------------------------------------------------*;
%_eg_conditional_dropds(TABUAS.tabua_pensao_djxx_mas4);
proc iml;
	USE TABUAS.TABUA_SERVICO_NORMAL_TEMP;
		read all var {COL2 COL1 COL17} into dx_i where (COL2 = 2);
		read all var {COL2 COL1 COL29} into djx_i where (COL2 = 1);
	CLOSE;

	qtdRows_dx = nrow(dx_i);
	qtdRows_djx = nrow(djx_i);
	tabua_pensao_temp = J((qtdRows_dx * qtdRows_djx), 5, 0);
	c = 1;

	do a = 1 to qtdRows_dx;
		do b = 1 to qtdRows_djx;
			tabua_pensao_temp[c, 1] = 4;
			tabua_pensao_temp[c, 2] = dx_i[a, 1];
			tabua_pensao_temp[c, 3] = dx_i[a, 2];
			tabua_pensao_temp[c, 4] = djx_i[b, 2];
			tabua_pensao_temp[c, 5] = round(djx_i[b, 3] * dx_i[a, 3], &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_djxx_mas4 from tabua_pensao_temp;
		append from tabua_pensao_temp;
	close;
quit;

%_eg_conditional_dropds(TABUAS.TRANSP_PENSAO_DJXX_MAS4, TABUAS.SORTTempTableSorted);
PROC SORT
	DATA=TABUAS.TABUA_PENSAO_DJXX_MAS4(KEEP=COL5 COL1 COL2 COL4)
	OUT=TABUAS.SORTTempTableSorted;
	BY COL1 COL2 COL4;
RUN;
PROC TRANSPOSE DATA=TABUAS.SORTTempTableSorted
	OUT=TABUAS.TRANSP_PENSAO_DJXX_MAS4
	PREFIX=Column
	NAME=Source
	LABEL=Label;
	BY COL1 COL2 COL4;
	VAR COL5;
RUN; 
%_eg_conditional_dropds(TABUAS.SORTTempTableSorted);

proc sql;
	alter table TABUAS.TRANSP_PENSAO_DJXX_MAS4
	drop column col1, col2, col4, Source;
run;

PROC SQL;
	CREATE TABLE TABUAS.TABUA_PENSAO_DJXX AS 
		SELECT * FROM TABUAS.tabua_pensao_djxx_fem1
 		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_djxx_mas1
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_fem2
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_mas2
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_fem3
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_mas3
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_fem4
		OUTER UNION CORR
		SELECT * FROM TABUAS.tabua_pensao_djxx_mas4;
RUN;

proc sql;
	CREATE TABLE TABUAS.TABUA_PENSAO_DJXX AS 
		SELECT t1.COL1 AS IdTipoTabua,
				t1.COL2 AS CdSexo,
				t1.COL3 AS IddParti,
				t1.COL4 AS IddConju,
				t1.COL5 FORMAT=COMMAX24.3 AS VlProb
		FROM TABUAS.TABUA_PENSAO_DJXX t1
		order by t1.col1, t1.col2, t1.COL3, t1.COL4;
run;

* ---------------------------------------------------- *;
* --- tabua pensao Njx:x_M:F participante feminino --- *;
* ---------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_fem1);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_FEM1;
		read all var _all_ into djxx;
	close;

	qtdRows = nrow(djxx);
	qtdCols = ncol(djxx);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

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

			tabua_pensao_njxx[c, 1] = 1;
			tabua_pensao_njxx[c, 2] = 1;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_fem1 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* ----------------------------------------------------- *;
* --- tabua pensao Njx:x_F:M participante masculino --- *;
* ----------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_mas1);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_MAS1;
		read all var _all_ into djxx;
	close;

	qtdRows = nrow(djxx);
	qtdCols = ncol(djxx);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

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

			tabua_pensao_njxx[c, 1] = 1;
			tabua_pensao_njxx[c, 2] = 2;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_mas1 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* --------------------------------------------------------------- *;
* --- tabua pensao Njx:x_M:F_i participante feminino invalido --- *;
* --------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_fem2);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_FEM2;
		read all var _all_ into djxx_i;
	close;

	qtdRows = nrow(djxx_i);
	qtdCols = ncol(djxx_i);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxx_i[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 2;
			tabua_pensao_njxx[c, 2] = 1;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_fem2 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* ---------------------------------------------------------------- *;
* --- tabua pensao Njx:x_F:M_i participante masculino invalido --- *;
* ---------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_mas2);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_MAS2;
		read all var _all_ into djxx_i;
	close;

	qtdRows = nrow(djxx_i);
	qtdCols = ncol(djxx_i);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxx_i[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 2;
			tabua_pensao_njxx[c, 2] = 2;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_mas2 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* ------------------------------------------------------------------------- *;
* --- tabua pensao Njx:x_M:F_i participante feminino e conjuge invalido --- *;
* ------------------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_fem3);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_FEM3;
		read all var _all_ into djxxi_;
	close;

	qtdRows = nrow(djxxi_);
	qtdCols = ncol(djxxi_);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxxi_[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 3;
			tabua_pensao_njxx[c, 2] = 1;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_fem3 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* -------------------------------------------------------------------------- *;
* --- tabua pensao Njx:x_F:M_i participante masculino e conjuge invalido --- *;
* -------------------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_mas3);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_MAS3;
		read all var _all_ into djxxi_;
	close;

	qtdRows = nrow(djxxi_);
	qtdCols = ncol(djxxi_);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxxi_[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 3;
			tabua_pensao_njxx[c, 2] = 2;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_mas3 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* ---------------------------------------------------------------------------------- *;
* --- tabua pensao Njx:x_M:Fii participante feminino invalido e conjuge invalido --- *;
* ---------------------------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_fem4);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_FEM4;
		read all var _all_ into djxxii;
	close;

	qtdRows = nrow(djxxii);
	qtdCols = ncol(djxxii);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxxii[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 4;
			tabua_pensao_njxx[c, 2] = 1;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_fem4 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

* ----------------------------------------------------------------------------------- *;
* --- tabua pensao Njx:x_F:Mii participante masculino invalido e conjuge invalido --- *;
* ----------------------------------------------------------------------------------- *;
%_eg_conditional_dropds(TABUAS.tabua_pensao_njxx_mas4);
proc iml;
	use TABUAS.TRANSP_PENSAO_DJXX_MAS4;
		read all var _all_ into djxxii;
	close;

	qtdRows = nrow(djxxii);
	qtdCols = ncol(djxxii);
	tabua_pensao_njxx = J(qtdRows * qtdCols, 5, 0);
	c = 1;
	iddMax = 125;

	do a = 0 to iddMax;
		do b = 0 to iddMax;
			d = a + 1;
			e = b + 1;
			soma = 0;

			do while (d <= qtdRows & e <= qtdCols);
				soma = soma + djxxii[e, d];
				d = d + 1;
				e = e + 1;
			end;

			tabua_pensao_njxx[c, 1] = 4;
			tabua_pensao_njxx[c, 2] = 2;
			tabua_pensao_njxx[c, 3] = a;
			tabua_pensao_njxx[c, 4] = b;
			tabua_pensao_njxx[c, 5] = round(soma, &vRoundProb);
			c = c + 1;
		end;
	end;

	create TABUAS.tabua_pensao_njxx_mas4 from tabua_pensao_njxx;
		append from tabua_pensao_njxx;
	close;
quit;

PROC SQL;
	CREATE TABLE TABUAS.TABUA_PENSAO_NJXX AS 
		SELECT * FROM TABUAS.tabua_pensao_njxx_fem1
 		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_mas1
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_fem2
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_mas2
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_fem3
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_mas3
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_fem4
		OUTER UNION CORR 
		SELECT * FROM TABUAS.tabua_pensao_njxx_mas4;
QUIT;

proc sql;
	create table TABUAS.tabua_pensao_njxx as
	select t1.COL1 AS IdTipoTabua,
			t1.COL2 AS CdSexo,
			t1.COL3 AS IddParti,
			t1.COL4 AS IddConju,
			t1.COL5 format=commax30.3 AS VlProb
	from TABUAS.TABUA_PENSAO_NJXX t1
	order by t1.col1, t1.col2, t1.COL3, COL4;
run;

PROC SQL;
	DROP TABLE  TABUAS.TRANSP_PENSAO_DJXX_FEM1,
				TABUAS.TRANSP_PENSAO_DJXX_FEM2,
				TABUAS.TRANSP_PENSAO_DJXX_FEM3,
				TABUAS.TRANSP_PENSAO_DJXX_FEM4,
				TABUAS.TRANSP_PENSAO_DJXX_MAS1,
				TABUAS.TRANSP_PENSAO_DJXX_MAS2,
				TABUAS.TRANSP_PENSAO_DJXX_MAS3,
				TABUAS.TRANSP_PENSAO_DJXX_MAS4,
				TABUAS.TABUA_PENSAO_DJXX_FEM1,
				TABUAS.TABUA_PENSAO_DJXX_FEM2,
				TABUAS.TABUA_PENSAO_DJXX_FEM3,
				TABUAS.TABUA_PENSAO_DJXX_FEM4,
				TABUAS.TABUA_PENSAO_DJXX_MAS1,
				TABUAS.TABUA_PENSAO_DJXX_MAS2,
				TABUAS.TABUA_PENSAO_DJXX_MAS3,
				TABUAS.TABUA_PENSAO_DJXX_MAS4,
				TABUAS.TABUA_PENSAO_NJXX_FEM1,
				TABUAS.TABUA_PENSAO_NJXX_FEM2,
				TABUAS.TABUA_PENSAO_NJXX_FEM3,
				TABUAS.TABUA_PENSAO_NJXX_FEM4,
				TABUAS.TABUA_PENSAO_NJXX_MAS1,
				TABUAS.TABUA_PENSAO_NJXX_MAS2,
				TABUAS.TABUA_PENSAO_NJXX_MAS3,
				TABUAS.TABUA_PENSAO_NJXX_MAS4;
QUIT;*/