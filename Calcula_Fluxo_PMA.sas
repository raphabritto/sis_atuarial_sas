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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {salario_contrib} into salario_contrib;
				read all var {flg_manutencao_saldo} into is_manut_saldo;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {apxa} into apxa;
				read all var {qx} into qx;
				read all var {pxs} into pxs;
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
					read all var {aposentado} into aposentado;
					read all var {morto} into morto;
					read all var {ativo} into ativo;
					read all var {valido} into valido;
					read all var {ligado} into ligado;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_pma = J(qtd_ativos, 1, 0);
				pagamento_pma = J(qtd_ativos, 1, 0);
				despesa_pma = J(qtd_ativos, 1, 0);
				despesa_vp_pma = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					taxa_juros_cober = taxas_juros[t1[a] + 1];

					if (&tipoCalculo = 2) then do;
						apxa[a] = aposentado[a];
						qx[a] = morto[a] * ativo[a] * valido[a] * ligado[a];
						pxs[a] = 1;
					end;

					v = 0;

					if (&CdPlanBen ^= 1 & is_manut_saldo[a] = 0) then do;
						beneficio_pma[a] = max(0, max(&LimPecMin, round((salario_contrib[a] / &FtBenEnti) * &peculioMorteAtivo, 0.01)));

						pagamento_pma[a] = max(0, round(beneficio_pma[a] * qx[a] * (1 - apxa[a]), 0.01));
						despesa_pma[a] = pagamento_pma[a];
						v = max(0, 1 / ((1 + taxa_juros_cober) ** t1[a]));
						despesa_vp_pma[a] = max(0, round(pagamento_pma[a] * v * pxs[a], 0.01));
					end;
				END;

				create temp.ativos_fluxo_pma_tp&tipoCalculo._s&s. var {id_participante t1 beneficio_pma pagamento_pma despesa_pma despesa_vp_pma};
					append;
				close temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_pma_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;
				 class t1;
				 var despesa_pma despesa_vp_pma;
				 format despesa_pma commax18.2 despesa_vp_pma commax18.2;
				 output out= work.ativos_despesa_pma_tp&tipoCalculo._s&s. sum=;
			run; 

			%_eg_conditional_dropds(fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_pma_tp&tipoCalculo._s&s.;
				if cmiss(t1) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_pma_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pma_tp&tipoCalculo._s&s.;
				 class id_participante;
				 var despesa_vp_pma;
				 format despesa_vp_pma commax18.2;
				 output out= work.ativos_encargo_pma_tp&tipoCalculo._s&s. sum=;
			run; 

			%_eg_conditional_dropds(fluxo.ativos_encargo_pma_tp&tipoCalculo._s&s.);
			data fluxo.ativos_encargo_pma_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_pma_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;
		%end;
	%end;
%mend;
%calculaFluxoPma;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
