*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;


%macro calculaFluxoPma;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.);

		proc iml;
			USE cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t SalConPrjEvol flg_manutencao_saldo} into ativos;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {apxa qx pxs} into fatores;
			close cobertur.ativos_fatores;

			if (&tipoCalculo = 1) then do;
				use premissa.taxa_juros;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros;
			end;
			else if (&tipoCalculo = 2) then do;
				use premissa.taxa_juros_s&s.;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros_s&s.;

				use cobertur.ativos_fatores_estoc_s&s.;
					read all var {aposentadoria morto ativo valido ligado} into fatores_estoc;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_pma = J(qtsObs, 6, 0);
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					SalConPrjEvol = ativos[a, 3];
					flg_manutencao_saldo = ativos[a, 4];

					taxa_juros_cober = taxas_juros[t_cober + 1];

					if (&tipoCalculo = 1) then do;
						apxa = fatores[a, 1];
						qx	 = fatores[a, 2];
						pxs	 = fatores[a, 3];
					end;
					else if (&tipoCalculo = 2) then do;
						apxa = fatores_estoc[a, 1];
						qx 	 = fatores_estoc[a, 2] * fatores_estoc[a, 3] * fatores_estoc[a, 4] * fatores_estoc[a, 5];
						pxs  = 1;
					end;

					pagamento = 0;
					beneficio = 0;
					despesa = 0;
					despesaVP = 0;
					v = 0;

					if (&CdPlanBen ^= 1 & flg_manutencao_saldo = 0) then do;
/*						if (t_cober = t_fluxo) then do;*/
							beneficio = max(0, max(&LimPecMin, round((SalConPrjEvol / &FtBenEnti) * &peculioMorteAtivo, 0.01)));

							pagamento = max(0, round(beneficio * qx * (1 - apxa), 0.01));
							despesa = pagamento;
							v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));
							despesaVP = max(0, round(pagamento * v * pxs, 0.01));
/*						end;*/
					end;

					fluxo_pma[a, 1] = ativos[a, 1];
					fluxo_pma[a, 2] = ativos[a, 2];
					fluxo_pma[a, 3] = beneficio;
					fluxo_pma[a, 4] = pagamento;
					fluxo_pma[a, 5] = despesa;
					fluxo_pma[a, 6] = despesaVP;
				END;

				create temp.ativos_fluxo_pma_tp&tipoCalculo._s&s. from fluxo_pma[colname={'id_participante' 'tCober' 'BeneficioPMA' 'PagamentoPMA' 'DespesaPMA' 'DespesaVpPMA'}];
					append from fluxo_pma;
				close temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;

				free fluxo_pma ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.pma_ativos&a.;*/
/*			merge determin.pma_ativos&a. work.pma_deterministico_ativos;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format BeneficioPMA commax14.2 PagamentoPMA commax14.2 DespesaPMA commax14.2 DespesaVpPMA commax14.2 v_PMA 12.8;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_pma_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;
			 class tCober;
			 var DespesaPMA DespesaVpPMA;
			 output out= work.ativos_despesa_pma_tp&tipoCalculo._s&s. sum=;
		run; 

		%_eg_conditional_dropds(fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_pma_tp&tipoCalculo._s&s.;
			if cmiss(tCober) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_pma_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var DespesaVpPMA;
			 output out= work.ativos_encargo_pma_tp&tipoCalculo._s&s. sum=;
		run; 

		%_eg_conditional_dropds(fluxo.ativos_encargo_pma_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_pma_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_pma_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calculaFluxoPma;

proc datasets library=work kill memtype=data nolist;
	run;
quit;


/*
%_eg_conditional_dropds(determin.pma_ativos);
data determin.pma_ativos;
	set determin.pma_ativos1 - determin.pma_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete pma_ativos1 - pma_ativos&numberOfBlocksAtivos;
run;
*/



