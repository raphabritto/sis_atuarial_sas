
%_eg_conditional_dropds(cobertur.reserv_matem_assistidos);
proc sql;
	create table cobertur.reserv_matem_assistidos as
	select apo.id_participante,
		   apo.ResMatApo,
		   apo.ResMatPen,
		   fut.ResMatFut,
		   pms.ResMatPms,
		   max(0, sum(apo.ResMatApo + apo.ResMatPen + fut.ResMatFut + pms.ResMatPms)) format=commax18.2 as ResMatTotal,
			(case
		   		when apo.CdCopensao is null
					then 1
					else max(0, (apo.ResMatPen / apo.ResMatPenTemp))
			end) format=10.6 as ftFluxoCopen
	from partic.assistidos a1
	inner join cobertur.apo_assistidos apo on (a1.id_participante = apo.id_participante)
	inner join cobertur.fut_assistidos fut on (a1.id_participante = fut.id_participante)
	inner join cobertur.pms_assistidos pms on (a1.id_participante = pms.id_participante)
	group by a1.id_participante
	order by a1.id_participante;
quit;