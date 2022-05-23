create or replace procedure PR_CREAR_CUOTAS_PROC
(
prestamo   INT,
tprestamo  INT,
funcion   VARCHAR2,
plazo     INT,
institucion INT, --AGG
fecha_inicio in out DATE
--fecha_primer_pago  date DEFAULT null 
)

is

fecha_primer_pago  date ;
-- nuevo
paga_diciembre   	CHAR(2);
cuota_fija    	CHAR(2);
pagos_dia_fijo   	CHAR(2);
dia_fijo   INT;
dias_primer_pago  INT;
frecuencia_cuota   VARCHAR2(12);
dias_gracia_mora   INT;
evitar_feriados_cuota  	CHAR(2);
periodo_cap   INT;
periodo_int    INT;
---- nuevo
dia_ajuste int;
dias_base int;
periodicidad_cuota_dias int;
contador_cuota INT;
fecha_inicio2 DATE;
fecha_ini_tmp DATE;
fecha_ven_tmp DATE;
fecha_aux date;
n_count int;
es_feriado INT;
var int;
dia int;
mes int;
fecha_aux2 date;
diaFinMes int;
meses_periodo int;

mesDic INT; --MES DICIEMBRE

-- PROCESO DE CREACION DE CUOTAS DEL PLAN DE PAGOS
-- OBJETIVO: Este procedimiento creará el plan de pagos para una operación nueva.
--           y generará los registros en la tabla pr_cuotas_pr
--           TOMAR EN CUENTA QUE EL PLAZO NO SON MESES, SINO CANTIDAD DE CUOTAS

BEGIN

IF funcion = 'I' then
    SELECT pr_paga_diciembre, 
            pr_cuota_fija, 
            pr_pagos_dia_fijo,
            PR_DIA_FIJO,
            pr_dias_primer_pago,
            pr_frecuencia_cuota,
           -- pr_plazo,
            pr_dias_gracia_mora_cuota,
            pr_evitar_feriados_cuota,
            pr_periodos_capital,
            pr_periodos_interes,
            PR_fecha_inicio --,
            --pr_fecha_primer_pago
    INTO 
        paga_diciembre,
        cuota_fija,
        pagos_dia_fijo,
        dia_fijo,
        dias_primer_pago, 
        frecuencia_cuota,  
       -- plazo,  
        dias_gracia_mora,  
        evitar_feriados_cuota, 
        periodo_cap,
        periodo_int,
        fecha_inicio --,
        --nuevo
        --fecha_primer_pago

    FROM PR_PRESTAMO WHERE PR_ID = prestamo;

    IF frecuencia_cuota = 'DIARIO' then 
        dias_base := 1;
        meses_periodo :=0;
        elsif frecuencia_cuota = 'MENSUAL' then 
            dias_base := 30; -- CAMBIADO A 31 DE 30
            meses_periodo :=1; 
            elsif frecuencia_cuota = 'SEMESTRAL' then 
                dias_base := 180;
                meses_periodo :=6; 
                    elsif frecuencia_cuota = 'ANUAL'  then
                        dias_base := 360;
                        meses_periodo :=12;
                        elsif frecuencia_cuota = 'TRIMESTRAL'  then
                            dias_base := 90;
                            meses_periodo :=3;
                            elsif frecuencia_cuota = 'CUATRIMESTRE'  then
                                dias_base := 120;
                                meses_periodo :=4;
                                elsif frecuencia_cuota = 'OCTOMESTRE'  then
                                    dias_base := 240;
                                    meses_periodo :=8; 

    END if;

    periodicidad_cuota_dias := dias_base * periodo_int;
    contador_cuota := 1;
    fecha_ini_tmp := fecha_inicio;
    fecha_ven_tmp := null;
    fecha_primer_pago := null;
    dia_ajuste := 0;

    While contador_cuota <= plazo
    LOOP  
    if dias_base = 1 then
          fecha_ven_tmp := fecha_ini_tmp + 1;
    else   

        if contador_cuota = 1 then    -- primera cuota
            IF pagos_dia_fijo = 'SI' then
                fecha_ven_tmp := fecha_ini_tmp + dias_base;

                ---NUEVO
                if dias_primer_pago > 0 then
                    fecha_ven_tmp := fecha_ini_tmp + dias_primer_pago ;
                    select EXTRACT(Day FROM fecha_ven_tmp) into dia from dual;
                END IF;
                --NUEVO

                /*IF dias_base = 30 then
                   --fecha_ven_tmp := fecha_ini_tmp + dias_base ;
                   select EXTRACT(Day FROM fecha_ven_tmp) into dia from dual; 
          
                   if dia < dia_fijo then
                      fecha_ven_tmp := fecha_ven_tmp + (dia_fijo - dia) ;
                     --PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                     --fecha_ven_tmp :=  PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                   END IF;
                else-- dias_base <> 30 then */
                    /*  probad fecha_aux2 := ADD_MONTHS(fecha_ini_tmp, meses_periodo);
                        diaFinMes := EXTRACT(DAY FROM LAST_dAY(fecha_aux2));

                     if  EXTRACT(month FROM fecha_aux2) <> 2  and diaFinMes < dia_fijo then 
                        fecha_ven_tmp := fecha_aux2;
                    else  probad */
                        select EXTRACT(Day FROM fecha_ven_tmp) into dia from dual; 
          
                        if dia < dia_fijo then
                           fecha_ven_tmp := fecha_ven_tmp + (dia_fijo - dia) ;
                            --PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                            --fecha_ven_tmp :=  PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                        end if;
                    -- probad end if;
                --end if  ;  
            else 
            --dias_primer_pago := (fecha_inicio + (dias_base * periodo_int)) - trunc(fecha_inicio); -- comentar 
            --IF  fecha_primer_pago = null then -- EL USARIO NO INGRESA FECHA DE PRIMER PAGO DEL CLIENTE
                if dias_primer_pago > 0 then
                    fecha_ven_tmp := fecha_ini_tmp + dias_primer_pago ;--+ (dias_base * periodo_int);
                else --dias_primer_pago = 0 
                    fecha_ven_tmp := fecha_ini_tmp + dias_base;
                end if; 

            end if;

        ELSE -- PARA EL RESTO DE CUOTAS
            fecha_ven_tmp := fecha_ini_tmp + dias_base ;--* periodo_int);

            IF pagos_dia_fijo = 'SI' then
               
                select EXTRACT(Month FROM fecha_ini_tmp) into mes from dual; 
                
                --IF mes = 1 then
                    fecha_aux2 := ADD_MONTHS(fecha_ini_tmp, meses_periodo); -- fecha auxiliar se le asigna 1 mes despues, en caso de mensual
                    diaFinMes := EXTRACT(DAY FROM LAST_dAY(fecha_aux2)); -- se trae el dia de la fecha auxiliar
                    
                    if diaFinMes < dia_fijo then -- si el ultimo dia del mes es menor al dia fijo
                        fecha_ven_tmp := fecha_aux2; --- se le asigna la fecha auxiliar
                    else
                        select EXTRACT(Month FROM fecha_ven_tmp) into mes from dual; 
                        IF mes = 3 then
                            dia_ajuste := dias_base - (EXTRACT(DAY FROM LAST_dAY(fecha_ini_tmp)));
                            fecha_ven_tmp := fecha_ven_tmp  - dia_ajuste;
                            dia_ajuste := 0;
                        END IF;        


                        select EXTRACT(Day FROM fecha_ven_tmp) into dia from dual; 
                        if dia < dia_fijo then
                            fecha_ven_tmp := fecha_ven_tmp + (dia_fijo - dia) ;

                            --nuevo loop, si el dia es mayor al dia fijo, 
                        elsif dia > dia_fijo then
                            fecha_ven_tmp := fecha_ven_tmp + (dia_fijo - dia) ;
                            --fecha_ven_tmp := fecha_ven_tmp - (dia -dia_fijo ) ;
                            --while dia > dia_fijo 
                            
                        /*A fecha inicio, debes sumarle los días de la frecuencia (30 si es mensual) -> Fecha_base. 
                        Si el día de esa fecha_base (función de obtener el día de una fecha: day() en SQL) 
                        es diferente al día de pago, sumas a la Fecha_base + (dia_pago - day(fecha_base)).*/


                            -- nuevo
                            --PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                            --fecha_ven_tmp :=  PR_DIA_HABIL_PROC(fecha_ven_tmp); LLAMAR RUTINA VALIDAR DIA HABIL
                        END IF;
                    end if;


            END IF; 


        END IF;

        -- fecha_aux := fecha_ven_tmp;

        /*-- Si no paga en diciembre saltar un mes
        if paga_diciembre = 'NO' THEN
            fecha_ven_tmp := ADD_MONTHS(fecha_ven_tmp, 1); --CONSIDERAR EL AJUSTE PARA QUE COINCIDA CON EL DÍA DE PAGO (volver a hacer la consideración de @dia_ajuste)
        end if;*/

    end if; 
    
    -- ACTIVÉ ESTO NUEVO


                -- NO PAGA DICIEMBRE
        IF paga_diciembre = 'NO' then
            select EXTRACT(Month FROM fecha_ven_tmp) into mesDic from dual; 

            if mesDic = 12 and ( frecuencia_cuota = 'MENSUAL' OR frecuencia_cuota = 'SEMESTRAL' )then
                fecha_ven_tmp := ADD_MONTHS(fecha_ven_tmp, 1);
            end if;
        end if; -- NO PAGA DICIEMBRE NUEVO 2022 ENERO 12
    
        -- Verificar si aplica feriados
        if evitar_feriados_cuota = 'SI' then
                ES_FERIADO := 0;
                BEGIN
                while ES_FERIADO = 0  
                LOOP
                    select fecha_ven_tmp + 1 INTO fecha_ven_tmp from PR_DIAS_FERIADOS
                    WHERE DF_FECHA = fecha_ven_tmp;
                    /*IF SQL%ROWCOUNT = FALSE THEN
                        ES_FERIADO := 1;
                    END IF;*/
                END LOOP;
                
                EXCEPTION
                WHEN NO_DATA_FOUND THEN 
                ES_FERIADO := 1;
                END;
        end if;

    -- ACTIVÉ ESTO NUEVO


            /*-- Verifica si permite primer pago o tiene dias de pago fijo
            if pagos_dia_fijo = 'SI' and contador_cuota = 1 then
                select EXTRACT(Day FROM fecha_aux ) into  dia_fijo from dual; -- dia_fijo = dia(fecha_aux) -> Fecha original de pag
            END IF; */


    
        INSERT INTO PR_CUOTAS_PR
            (
            CP_ID,
            CP_ID_INSTITUCION,
            CP_ID_PRESTAMO,
            CP_NUMERO_CUOTA,
            CP_FECHA_INICIO,
            CP_FECHA_FIN,
            CP_DIAS_CUOTA,
            CP_DIAS_GRACIA_MORA,
            CP_DIAS_ATRASO,
            CP_ESTADO
        )
        
        VALUES (
            PR_CUOTAS_PR_SEC.NEXTVAL, 
        institucion,
        prestamo,
        contador_cuota,
        fecha_ini_tmp,
        fecha_ven_tmp,
        trunc(fecha_ven_tmp) - fecha_ini_tmp,
        dias_gracia_mora,
        0,
        'NO VIGENTE'
        );

        contador_cuota := contador_cuota + 1;
        fecha_ini_tmp :=  fecha_ven_tmp; -- fecha_aux;

    END LOOP; 

END IF;
END;

