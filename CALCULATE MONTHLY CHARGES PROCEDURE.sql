create or replace PROCEDURE PR_CREAR_VALORES_PLAN_PAGOS_PROC (
    institucion     int,
    prestamo        int,
    tprestamo       int,
    plazo IN OUT    int,
    funcion         varchar ,    -- 'S' Sobre saldo
    cuota_base_user number
)
is

/* PROCESO DE DISTRIBUCIÓN DE PLAN DE PAGOS
   OBJETIVO: Este proceso crea los valores del plan de pagos, 
   de acuerdo a los cargos parametrizados para la operación.
    Primera versión, de cálculo sobre saldo 
*/

base_calculo            int; 
cuota_fija              char(2);

saldo_capital           number;
num_cuota               int;
dias_cuota              int;

tasa_interes            number;
tasa_feci               number;
i                       number;
x                       int;
capital                 number;
num_cuotas              int;
cuota_prev_base         number;
cuota_base              number;
contador_cuota          int;
val_ultima_cuota        number;
valor_acum              number;
valor_cargo             number;
cargo                   varchar(16);
suma_cap                number; 
valor_cuota             number;
cuota_rem_cap           number; 
val_cap_tmp             number; 
interes_y_feci_mensual  number;
tot_cargos_capital      number;

cliente_id              int;
jubilado                varchar(2);

frecuencia_capital      int;
frecuencia_interes      int;
monto_solicitado        number;
cargos_mensual          number;
seguros                 number;

delta                   number;
n_control               int;
w_error                 int;
ajuste_tmp              number;
max_interacciones       int;
w_mensaje               varchar(255);

-- OBTENER LOS VALORES DE CALCULO QUE AFECTAN LA DISTRIBUCION DE LA CUOTA
BEGIN
    -- MAXIMO NUMERO DE ITERACIONES
    max_interacciones := 30;

    SELECT  to_number(substr(pr_base_calculo,12,3)), -- hace SUBSTRING A CALENDARIO '360' o '365'
            pr_cuota_fija,
            PR_MONTO,
            PR_ID_CLIENTE, 
            PR_PERIODOS_CAPITAL,  
            PR_PERIODOS_INTERES 
      INTO 
            base_calculo,       -- indica si la base de calculo es 360 o 365
            cuota_fija,         -- Calculará cuota fija o capital constante
            monto_solicitado,   -- nuevo
            cliente_id, 
            frecuencia_capital, -- se asigna periodos_capital a frecuencia_capital
            frecuencia_interes
      FROM PR_PRESTAMO 
     WHERE PR_ID_INSTITUCION = institucion 
       AND PR_ID = prestamo;
    
    SELECT CL_JUBILADO 
      INTO jubilado 
      FROM pr_cliente 
     WHERE CL_INSTITUCION = institucion 
       and cl_ID = cliente_id;

    SELECT PR_VALOR    
      INTO tasa_interes
      FROM PR_CARGOS_PR  
     WHERE CP_ID_INSTITUCION = institucion
       AND CP_ID_PRESTAMO = prestamo
       AND PR_TIPO_CARGO = 'INTERES';

    IF jubilado = 'NO' THEN
        IF  monto_solicitado > 5000 THEN
            SELECT PR_VALOR 
              INTO tasa_feci
              FROM PR_CARGOS_PR  
             WHERE CP_ID_INSTITUCION = institucion
               AND CP_ID_PRESTAMO = prestamo
               AND PR_TIPO_CARGO = 'FECI';
        ELSE 
             tasa_feci := 0;
        END IF;
    ELSIF jubilado = 'SI' THEN
        tasa_feci := 0;
    END IF;

    tasa_interes := tasa_interes / 100;
    tasa_feci := tasa_feci / 100;
    SELECT (((tasa_interes + tasa_feci ) / 12 ) * (base_calculo/365) ) INTO i FROM dual  ; -- calcular i
   
   --@saldo_capital = cp_valor de la suma de los cargos = 'CAPITAL' de la tabla pr_cargos_pr
    SELECT sum(PR_VALOR) 
      INTO tot_cargos_capital 
      FROM pr_cargos_pr 
     WHERE CP_ID_INSTITUCION = institucion
       AND PR_TIPO_CARGO = 'CAPITAL' 
       AND CP_ID_PRESTAMO = prestamo;
     
    saldo_capital := tot_cargos_capital;

    -- Cargos mensuales
    SELECT NVL(sum(cp_monto),0) 
      INTO cargos_mensual
      FROM pr_cargos_pr 
     WHERE CP_ID_INSTITUCION = institucion
       AND PR_TIPO_CARGO = 'OTRO' 
       AND pr_tipo_cobro = 'MENSUAL'
       AND CP_ID_PRESTAMO = prestamo;

    -- Nuevo cargos SEGUROS 
    SELECT NVL(sum(cp_monto),0) 
      INTO seguros
      FROM pr_cargos_pr 
     WHERE CP_ID_INSTITUCION = institucion
       AND PR_TIPO_CARGO = 'SEGURO' 
       AND pr_tipo_cobro = 'MENSUAL'
       AND CP_ID_PRESTAMO = prestamo;
      
    -- SUMAR CARGOS MENSUALES Y SEGUROS
    cargos_mensual := cargos_mensual + seguros;

    -- Cuota previa a cargos mensuales 
    cuota_prev_base := round(saldo_capital * (i * ((1 + i)**plazo)) / (( 1 + i )**plazo - 1)*(frecuencia_capital/frecuencia_interes),2); 
    cuota_prev_base := cuota_prev_base + cargos_mensual;

    IF cuota_base_user <> 0 THEN
        cuota_prev_base := cuota_base_user;
    END IF;

    -- Añadir a la cuota base un delta (@delta) para ajustar la cuota
    w_error           := 0;
    delta             := 0;
    n_control         := 1;
    val_ultima_cuota  := 0;
    valor_cuota       := cuota_prev_base;
    ajuste_tmp        := 2;

    WHILE n_control <= max_interacciones
     LOOP
            -- Borrar SIEMPRE pr_valores_pr para el préstamo
            DELETE pr_valores_pr 
             WHERE VP_ID_INSTITUCIÓN = institucion 
               AND VP_ID_PRESTAMO = prestamo;
             
            contador_cuota := 1;
            saldo_capital := tot_cargos_capital;
            
            --Buqle A de 1 a N (cuotas) -- Número de cuotas del plan de pagos
            WHILE contador_cuota <= plazo
            LOOP 
                --->  asignar de la tabla tabla pr_cuotas_pr.cp_dias_cuota
                num_cuota := contador_cuota;
                
                SELECT cp_dias_cuota 
                  INTO dias_cuota 
                  FROM pr_cuotas_pr 
                 WHERE CP_ID_INSTITUCION = institucion
                   AND cp_id_prestamo = prestamo 
                   AND CP_NUMERO_CUOTA = num_cuota ; 

                interes_y_feci_mensual := 0 ;
              
                --Bucle B de 1 a N (cargos) <> 'CAPITAL'-- Cargos tipo 'Mensual'
                FOR x IN (
                SELECT cp_id_cargo,
                       pr_tipo_cargo,
                       pr_valor,
                       pr_accrual,
                       cp_monto                
                  FROM pr_cargos_pr
                 WHERE CP_ID_INSTITUCION = institucion
                   AND cp_id_prestamo = prestamo
                   AND pr_tipo_cargo <> 'CAPITAL'
                   AND pr_tipo_cobro = 'MENSUAL'
                   AND CP_CREAR_SIEMPRE = 'S')
                
                LOOP
                   -- accrual -> Valor pr_cargos_pr.cp_difiere -- Valor difiere S/N  confirmar ISAAC
                  valor_cargo := 0;
                  valor_acum  := 0;
        
                  IF x.pr_tipo_cargo not in ('INTERES', 'FECI', 'MORA') THEN -- Para cargos diferentes de INTERES, FECI y MORA
                        valor_cargo := x.pr_valor;
                      
                        IF x.pr_tipo_cargo in ('OTRO') THEN
                            valor_cargo := x.CP_MONTO;
                        END IF;
                   ELSIF  x.pr_tipo_cargo  = 'FECI' THEN  -- Para cargos tipo 'FECI'
                         valor_cargo := round((saldo_capital * tasa_feci / base_calculo * dias_cuota),2); 
                         interes_y_feci_mensual :=  interes_y_feci_mensual + valor_cargo;

                   ELSIF x.pr_tipo_cargo = 'INTERES' THEN -- Para el cargo tipo 'INTERES'
                          valor_cargo := round((saldo_capital * tasa_interes / base_calculo * dias_cuota),2); 
                          interes_y_feci_mensual :=  interes_y_feci_mensual + valor_cargo;
   			     END IF;

				 IF x.pr_accrual = 'SI' THEN
                      valor_acum := valor_cargo;
                 END IF;
 
                 INSERT INTO pr_valores_pr (   
                        vp_id,
                        vp_id_institución,
                        vp_id_prestamo,
                        vp_num_cuota, 
                        vp_codigo_cargo, 
                        vp_estado_cargo,
                        vp_cuota,
                        vp_acumulado,
                        vp_diferido,
                        vp_pagado,
                        VP_ID_CARGO,
                        vp_tipo_cargo     )
                    VALUES (
                        PR_valores_PR_SEC.NEXTVAL,
                        institucion,
                        prestamo,
                        num_cuota, 
                        x.cp_id_cargo, 
                        'NO VIGENTE',
                        valor_cargo,
                        valor_acum,
                        0,
                        0,
                        x.cp_id_cargo,
                        x.pr_tipo_cargo);
				END LOOP; 

                IF num_cuota = plazo THEN  -- Si el número de cuota es la última cuota, o el # del plazo, el saldo capital es el remanente 
                    cuota_rem_cap := saldo_capital;
                ELSE
                    -- Caso contrario, la cuota rem. de Capital es la Cuota base más interes, feci, cargos mensuales y  delta.
                    IF MOD(num_cuota,frecuencia_capital) = 0 THEN 
                        cuota_rem_cap := cuota_prev_base - interes_y_feci_mensual - cargos_mensual; 
                    ELSE
                        cuota_rem_cap := 0; 
                    END IF;					
                END IF;

                -- CONTROLA CUOTAS NEGATIVAS
                IF cuota_rem_cap < 0 THEN
                    BEGIN
                      IF num_cuota <> plazo AND round(abs(saldo_capital - cuota_rem_cap),2) > 0.01 AND delta <> 0 THEN
                        BEGIN
                         w_error := 1;
                         EXIT; -- SALE DEL BUCLE cuando no amortiza
                        END;
                      END IF;

                      IF cuota_base_user <> 0 THEN
                        BEGIN
                         w_error := 1;
                         EXIT;
                        END;
                      END IF;
                    END;
                END IF;

                -- ACTUALIZAR LA NUEVA CUOTA BASE PARA QUE DELTA CALCULE EN BASE A ESTE ULTIMO VALOR
                DECLARE
                CURSOR curCargosCap IS
                SELECT cp_id_cargo,
                       pr_tipo_cargo,
                       pr_valor
                  FROM pr_cargos_pr
                 WHERE CP_ID_INSTITUCION = institucion
                   AND cp_id_prestamo = prestamo
                   AND pr_tipo_cargo = 'CAPITAL';

                BEGIN

                FOR x IN curCargosCap 
                LOOP
                        val_cap_tmp := nvl(x.pr_valor,0);
                        cuota_rem_cap := nvl(cuota_rem_cap,0);

                        -- Prorrateo de cargos de capital
                        valor_cargo := cuota_rem_cap * (val_cap_tmp/tot_cargos_capital) ; 
                        valor_acum := valor_cargo; -- Siempre para tipos capital 

                    INSERT INTO pr_valores_pr (
                        vp_id,
                        vp_id_institución,
                        vp_id_prestamo,
                        vp_num_cuota, 
                        vp_codigo_cargo, 
                        vp_estado_cargo,
                        vp_cuota,
                        vp_acumulado,
                        vp_diferido,
                        vp_pagado,
                        VP_ID_CARGO,
                        VP_TIPO_CARGO )
                    VALUES (
                        PR_valores_PR_SEC.NEXTVAL,
                        institucion,
                        prestamo,
                        num_cuota, 
                        x.cp_id_cargo, 
                        'NO VIGENTE',
                        valor_cargo,
                        valor_acum,
                        0,
                        0,
                        x.cp_id_cargo,
                        x.pr_tipo_cargo);
                END LOOP; 	

                END;            
                  
                saldo_capital  := saldo_capital - cuota_rem_cap; 
                contador_cuota := contador_cuota + 1;
			END LOOP; 


		-- Se asigna el valor de la última cuota (rubros sumados)
        SELECT sum(vp_cuota) 
          INTO val_ultima_cuota 
          FROM pr_valores_pr 
         WHERE VP_ID_INSTITUCIÓN = institucion
           AND vp_id_prestamo = prestamo
           AND VP_NUM_CUOTA = plazo;

		SELECT sum(vp_cuota) 
          INTO cuota_base  
          FROM pr_valores_pr 
         WHERE VP_ID_INSTITUCIÓN = institucion
           AND vp_id_prestamo = prestamo
           AND VP_NUM_CUOTA = (1 * frecuencia_capital); -- SE CONSIDERA LA PRIMERA CUOTA BASE 

        -- CONTROLES DE SALIDA Y CALCULO PARA NUEVA BUCLE
        -- TERMINA LA DISTRIBUCIÓN SIN ERROR, ya se por que se calculó con cuota ingresada o es capital al vencimiento)
        IF cuota_base_user <> 0 or (num_cuota = frecuencia_capital) or abs(val_ultima_cuota - cuota_base) <= (0.01*plazo) then
          BEGIN
            IF val_ultima_cuota < 0 THEN
              w_error := 1;
            END IF;

            EXIT; 
          END;
        END IF;

        -- AJUSTA LOS VALORES PARA SIGUIENTE BUCLE
        IF val_ultima_cuota < 0 THEN
          BEGIN
            -- Cuando la ultima cuota es negativa, se debe calcular de nuevo el delta, pero con una aproximación
            -- mayor en la dividendo del delta (curva menor de aproximación)
            cuota_prev_base := valor_cuota;
            ajuste_tmp := ajuste_tmp + 1;
            delta := 0;
          END;
        ELSE
          BEGIN
             delta := abs(round(((val_ultima_cuota - cuota_prev_base) / plazo / ajuste_tmp),2));

            -- Si delta es 0, se encontró la mejor aproximación.
             IF delta = 0 THEN
               EXIT;
             END IF;

             cuota_prev_base := cuota_prev_base + delta;
          END;
        END IF;

        n_control := n_control + 1;

    END LOOP; 

    IF w_error = 1 THEN
      w_mensaje := 'La cuota ingresada no permite amortizar el monto financiado. Vuelva ingresar una nueva cuota o 0 para calcularla de forma automática.';
    END IF;

    -- No se pudo alcanzar la amortización
    IF val_ultima_cuota < 0 and n_control >= max_interacciones THEN
      w_error := 2;
      w_mensaje := 'No se logró encontrar una cuota que amortice el préstamo, por favor, pruebe reduciendo el plazo, la tasa o el monto';  
    END IF;

    DECLARE
    ERRORES EXCEPTION;
    BEGIN
        IF w_error <> 0 THEN
           RAISE ERRORES;
        END IF;
                                
        EXCEPTION

        WHEN ERRORES THEN
        raise_application_error(-20000, w_mensaje);
    END;    
    
END;
