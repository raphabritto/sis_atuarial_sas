
%_eg_conditional_dropds(work.assistidos_reserv_matem);
proc sql;
	create table work.reserv_matem_assistidos as
	select a1.id_participante,
/*		   apo.ResMatApo,*/
/*		   apo.ResMatPen,*/
/*		   fut.ResMatFut,*/
/*		   pms.ResMatPms,*/
		   max(0, sum(a1.ResMatApo + a1.ResMatPen + a1.ResMatFut + a1.ResMatPms)) format=commax18.2 as ResMatTotal,
			(case
		   		when a1.CdCopensao is null
					then 1
					else max(0, (a1.ResMatPen / a1.ResMatPenTemp))
			end) format=10.6 as ftFluxoCopen
	from cobertur.assistidos a1
/*	inner join cobertur.apo_assistidos apo on (a1.id_participante = apo.id_participante)*/
/*	inner join cobertur.fut_assistidos fut on (a1.id_participante = fut.id_participante)*/
/*	inner join cobertur.pms_assistidos pms on (a1.id_participante = pms.id_participante)*/
	group by a1.id_participante
	order by a1.id_participante;
quit;

data cobertur.assistidos;
	merge cobertur.assistidos work.reserv_matem_assistidos;
	by id_participante;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
