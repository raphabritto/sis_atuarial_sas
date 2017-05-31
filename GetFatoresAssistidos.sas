
%_eg_conditional_dropds(work.ASSISTIDOS_FATORES);
proc sql;
	create table work.ASSISTIDOS_FATORES as
	select t1.id_participante,
			t27.qx format=12.8 as qx_aj,
			t3.qxi format=12.8 as qxii_nr,
			(case
				when (t1.CdTipoBenefi = 1 or t1.CdTipoBenefi = 2) or (t1.CdTipoBenefi = 4 and t1.IddPartiCalc >= &MaiorIdad)
					then (max(0, ((t3.Nxcb / t3.Dxcb) - &Fb)))
					else 0
			end) format=12.8 AS ax,
			(case
				when t1.CdTipoBenefi = 3
					then (max(0, ((t3.Nxiicb / t3.Dxiicb) - &Fb)))
					else 0
			end) format=12.8 AS axii,
			(case
				when t1.CdTipoBenefi = 4 and t1.IddPartiCalc < &MaiorIdad
					then (max(0, ((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** (&MaiorIdad - t1.IddPartiCalc) - 1) / (((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** ((&MaiorIdad - t1.IddPartiCalc) - 1)) * ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) - &Fb * (1 - (1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** - (&MaiorIdad - t1.IddPartiCalc))))
					else 0
			end) format=12.8 AS anpen,
			max(0, (1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** - (&MaiorIdad - t1.IddFilJovCalc)) format=12.8 as descap,
			(case
				when t1.IddConjuCalc is null
					then 0
					else max(0, ((t4.Nxcb / t4.Dxcb) - &Fb))
			end) format=12.8 as ajx,
			(case
				when (t1.CdTipoBenefi = 1 or t1.CdTipoBenefi = 2) and (t1.IddConjuCalc is not null)
					then max(0, ((t6.njxx / t5.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxx,
			(case
				when t1.CdTipoBenefi = 3 and t1.IddConjuCalc is not null
					then max(0, ((t20.njxx / t19.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxx_i,
			(case
				when t1.IddFilInvCalc is not null
					then max(0, ((t7.Nxiicb / t7.Dxiicb) - &Fb))
					else 0
			end) format=12.8 as ajxii,
			(case
				when (t1.CdTipoBenefi = 1 or t1.CdTipoBenefi = 2) and (t1.IddFilInvCalc is not null)
					then max(0, ((t9.njxx / t8.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxxi_,
			(case
				when t1.CdTipoBenefi = 3 and t1.IddFilInvCalc is not null
					then max(0, ((t22.njxx / t21.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxxii,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else (max(0, ((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** (&MaiorIdad - t1.IddFilJovCalc) - 1) / (((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** ((&MaiorIdad - t1.IddFilJovCalc) - 1)) * ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) - &Fb * (1 - (1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** - (&MaiorIdad - t1.IddFilJovCalc))))
			end) format=12.8 as an1,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else max(0, (t10.Dxcb / t3.Dxcb))
			end) format=12.8 as dxn1_dx,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else max(0, ((t10.Nxcb / t10.Dxcb) - &Fb))
			end) format=12.8 as axn1,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else max(0, (t10.Dxiicb / t3.Dxiicb))
			end) format=12.8 as dxn1ii_dxii,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else max(0, ((t10.Nxiicb / t10.Dxiicb) - &Fb))
			end) format=12.8 as axn1ii,
			(case
				when t1.IddFilJovCalc is null and t1.IddConjuCalc is null
					then 0
					else max(0, (t10.lx / t3.lx))
			end) format=12.8 as lxn1_lx,
			(case
				when t1.IddFilJovCalc is null and t1.IddConjuCalc is null
					then 0
					else max(0, (t11.Dxcb / t4.Dxcb))
			end) format=12.8 as djxn1_djx,
			(case
				when t1.IddFilJovCalc is null and t1.IddConjuCalc is null
					then 0
					else max(0, ((t11.Nxcb / t11.Dxcb) - &Fb))
			end) format=12.8 as ajxn1,
			(case
				when t1.IddFilJovCalc is null and t1.IddConjuCalc is null
					then 0
					else max(0, (t11.lx / t4.lx))
			end) format=12.8 as ljxn1_ljx,
			(case
				when (t1.CdTipoBenefi = 1 or t1.CdTipoBenefi = 2) and (t1.IddConjuCalc is not null and t1.IddFilJovCalc is not null)
					then max(0, ((t13.njxx / t12.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxn1xn1,
			(case
				when t1.IddFilJovCalc is null
					then 0
					else max(0, (t10.lxii / t3.lxii))
			end) format=12.8 as lxn1ii_lxii,
			(case
				when t1.CdTipoBenefi = 3 and t1.IddFilJovCalc is not null
					then max(0, ((t24.njxx / t23.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxn1xn1_i,
			(case
				when t1.IddFilInvCalc is null and t1.IddFilJovCalc is null
					then 0
					else max(0, (t14.Dxiicb / t7.Dxiicb))
			end) format=12.8 as djxn1ii_djxii,
			(case
				when t1.IddFilInvCalc is null and t1.IddFilJovCalc is null
					then 0
					else max(0, ((t14.Nxiicb / t14.Dxiicb) - &Fb))
			end) format=12.8 as ajxn1ii,
			(case
				when t1.IddFilInvCalc is null and t1.IddFilJovCalc is null
					then 0
					else max(0, (t14.lxii / t7.lxii))
			end) format=12.8 as ljxn1ii_ljxii,
			(case
				when (t1.CdTipoBenefi = 1 or t1.CdTipoBenefi = 2) and (t1.IddFilInvCalc is not null and t1.IddFilJovCalc is not null)
					then max(0, ((t16.njxx / t15.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxn1xn1i_,
			(case
				when t1.CdTipoBenefi = 3 and (t1.IddFilInvCalc is not null and t1.IddFilJovCalc is not null)
					then max(0, ((t26.njxx / t25.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxn1xn1ii,
			max(0, (t3.Mxii / t3.'Dxii*'n)) format=12.8 as mxii_dxii,
			max(0, (t3.Mx / t3.'Dx*'n)) format=12.8 as mx_dx,
			max(0, ((t3.Mx - t28.Mx) / t3.'Dx*'n)) format=12.8 as mxn_dx
	from partic.ASSISTIDOS t1
	inner join work.taxa_juros txc on (txc.t = 0)
	inner join tabuas.tabuas_SERVICO_NORMAL t3 ON (t1.CdSexoPartic = t3.Sexo AND t1.IddPartiCalc = t3.Idade and t3.t = 0)
	left join tabuas.tabuas_SERVICO_NORMAL t4 on (t1.CdSexoConjug = t4.Sexo and t1.IddConjuCalc = t4.Idade and t4.t = 0)
	left join tabuas.tabuas_pensao_djxx t5 on (t1.CdSexoPartic = t5.Sexo and t1.IddPartiCalc = t5.idade_x and t1.IddConjuCalc = t5.idade_j and t5.Tipo = 1 and t5.t = 0)
	left join tabuas.tabuas_pensao_njxx t6 on (t1.CdSexoPartic = t6.Sexo and t1.IddPartiCalc = t6.idade_x and t1.IddConjuCalc = t6.idade_j and t6.Tipo = 1 and t6.t = 0)
	left join tabuas.tabuas_servico_normal t7 on (t1.CdSexoFilInv = t7.Sexo and t1.IddFilInvCalc = t7.Idade and t7.t = 0)
	left join tabuas.tabuas_pensao_djxx t8 on (t1.CdSexoPartic = t8.Sexo and t1.IddPartiCalc = t8.idade_x and t1.IddFilInvCalc = t8.idade_j and t8.Tipo = 3 and t8.t = 0)
	left join tabuas.tabuas_pensao_njxx t9 on (t1.CdSexoPartic = t9.Sexo and t1.IddPartiCalc = t9.idade_x and t1.IddFilInvCalc = t9.idade_j and t9.Tipo = 3 and t9.t = 0)
	left join tabuas.tabuas_servico_normal t10 on (t1.CdSexoPartic = t10.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t10.Idade and t10.t = 0)
	left join tabuas.tabuas_servico_normal t11 on (t1.CdSexoConjug = t11.Sexo and (t1.IddConjuCalc + &MaiorIdad - t1.IddFilJovCalc) = t11.Idade and t11.t = 0)
	left join tabuas.tabuas_pensao_djxx t12 on (t1.CdSexoPartic = t12.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t12.idade_x and (t1.IddConjuCalc + &MaiorIdad - t1.IddFilJovCalc) = t12.idade_j and t12.Tipo = 1 and t12.t = 0)
	left join tabuas.tabuas_pensao_njxx t13 on (t1.CdSexoPartic = t13.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t13.idade_x and (t1.IddConjuCalc + &MaiorIdad - t1.IddFilJovCalc) = t13.idade_j and t13.Tipo = 1 and t13.t = 0)
	left join tabuas.tabuas_servico_normal t14 on (t1.CdSexoFilInv = t14.Sexo and (t1.IddFilInvCalc + &MaiorIdad - t1.IddFilJovCalc) = t14.Idade and t14.t = 0)
	left join tabuas.tabuas_pensao_djxx t15 on (t1.CdSexoPartic = t15.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t15.idade_x and (t1.IddFilInvCalc + &MaiorIdad - t1.IddFilJovCalc) = t15.idade_j and t15.Tipo = 3 and t15.t = 0)
	left join tabuas.tabuas_pensao_njxx t16 on (t1.CdSexoPartic = t16.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t16.idade_x and (t1.IddFilInvCalc + &MaiorIdad - t1.IddFilJovCalc) = t16.idade_j and t16.Tipo = 3 and t16.t = 0)
	left join tabuas.tabuas_pensao_djxx t17 on (t1.CdSexoPartic = t17.Sexo and t1.IddPartiCalc = t17.idade_x and t1.IddFilInvCalc = t17.idade_j and t17.Tipo = 1 and t17.t = 0)
	left join tabuas.tabuas_pensao_njxx t18 on (t1.CdSexoPartic = t18.Sexo and t1.IddPartiCalc = t18.idade_x and t1.IddFilInvCalc = t18.idade_j and t18.Tipo = 1 and t18.t = 0)
	left join tabuas.tabuas_pensao_djxx t19 on (t1.CdSexoPartic = t19.Sexo and t1.IddPartiCalc = t19.idade_x and t1.IddConjuCalc = t19.idade_j and t19.Tipo = 2 and t19.t = 0)
	left join tabuas.tabuas_pensao_njxx t20 on (t1.CdSexoPartic = t20.Sexo and t1.IddPartiCalc = t20.idade_x and t1.IddConjuCalc = t20.idade_j and t20.Tipo = 2 and t20.t = 0)
	left join tabuas.tabuas_pensao_djxx t21 on (t1.CdSexoPartic = t21.Sexo and t1.IddPartiCalc = t21.idade_x and t1.IddFilInvCalc = t21.idade_j and t21.Tipo = 4 and t21.t = 0)
	left join tabuas.tabuas_pensao_njxx t22 on (t1.CdSexoPartic = t22.Sexo and t1.IddPartiCalc = t22.idade_x and t1.IddFilInvCalc = t22.idade_j and t22.Tipo = 4 and t22.t = 0)
	left join tabuas.tabuas_pensao_djxx t23 on (t1.CdSexoPartic = t23.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t23.idade_x and (t1.IddConjuCalc + &MaiorIdad - t1.IddFilJovCalc) = t23.idade_j and t23.Tipo = 2 and t23.t = 0)
	left join tabuas.tabuas_pensao_njxx t24 on (t1.CdSexoPartic = t24.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t24.idade_x and (t1.IddConjuCalc + &MaiorIdad - t1.IddFilJovCalc) = t24.idade_j and t24.Tipo = 2 and t24.t = 0)
	left join tabuas.tabuas_pensao_djxx t25 on (t1.CdSexoPartic = t25.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t25.idade_x and (t1.IddFilInvCalc + &MaiorIdad - t1.IddFilJovCalc) = t25.idade_j and t25.Tipo = 4 and t25.t = 0)
	left join tabuas.tabuas_pensao_njxx t26 on (t1.CdSexoPartic = t26.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t26.idade_x and (t1.IddFilInvCalc + &MaiorIdad - t1.IddFilJovCalc) = t26.idade_j and t26.Tipo = 4 and t26.t = 0)
	inner join tabuas.tabuas_servico_ajustada t27 on (t1.CdSexoPartic = t27.Sexo AND t1.IddPartiCalc = t27.Idade and t27.t = 0)
	left join tabuas.tabuas_servico_normal t28 on (t1.CdSexoPartic = t28.Sexo and &MaiorIdad = t28.Idade and t28.t = 0)
	order by t1.id_participante;
quit;