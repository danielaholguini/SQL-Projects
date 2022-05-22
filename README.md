# SQL-Projects
PL/SQL Project Examples

create or replace PROCEDURE PR_CREAR_PRESTAMO_PROC 
(
    COD  INT,
    INSTITUCION  INT,
    id_cliente  int,
    fecha_inicio  date,

    tipo_prestamo  int,

    FRECUENCIA VARCHAR,
    plazo_base  int,
    monto_base  number, -- ESTE ES EL MONTO SOLICITADO (Y EDITADO) MAS LOS CARGOS CAPITALIZADOS

    funcion  varchar,
    --Plazo  int,
    Periodo_capital  int,
    Periodo_interes  int,
    Paga_Diciembre  varchar,  
    Cuota_Fija  varchar,
    cuota_base_user number,
    monto_solicitado_editado number,
    oficina int,
    PAGOS_DIA_FIJO varchar
    
)
AS

fecha_primer_pago date;
dias_base int;
dia_fijo int;
dias_primer_pago int;
MONTO_SOLICITADO_EDIT number;

BEGIN

    IF FUNCION = 'I' then

        IF FRECUENCIA = 'DIARIO' then 
            dias_base := 1;
            elsif FRECUENCIA = 'MENSUAL' then 
                dias_base := 30;
                elsif FRECUENCIA = 'SEMESTRAL' then 
                    dias_base := 180;
                        elsif FRECUENCIA = 'ANUAL'  then
                            dias_base := 360;
        END if;



        INSERT into  PR_PRESTAMO(
        PR_ID, 
        pr_id_institucion,
        pr_id_cliente,
        pr_nombre, --c
        pr_estado ,  --c
        pr_numero,  --c
        pr_fecha_creacion, -- PENDEINTE  --c
        pr_fecha_inicio,  
        --pr_fecha_fin,-- PENDEINTE  --c
        pr_id_tprestamo,     
        pr_tipo_calculo,  -- t
        pr_segmento,      -- t
        pr_clase_prestamo, -- t
        pr_base_calculo, -- t
        pr_paga_diciembre, -- t
        pr_cuota_fija, -- t
        pr_pagos_dia_fijo, -- t
        pr_dia_fijo, -- t
        pr_dias_primer_pago, -- t
        pr_frecuencia_cuota, -- t
        pr_plazo,     
        pr_dias_gracia_mora_cuota,
        pr_evitar_feriados_cuota,
        pr_periodos_capital,
        pr_periodos_interes,
        pr_cuota_completa,
        pr_permite_pagos_extraordinarios,
        pr_pago_adelantado_extraordinario,
        pr_disminuye_cuota_plazo,
        pr_paga_cuota_cargos,
        pr_interes_acumulado_proyectado,
        pr_monto ,
        pr_tasa,   
        pr_cuota,  /**pendiente
        pr_pres_anterior, **pendiente
        --pr_reestructuración,
        --pr_nro_reestructuración,
        ---pr_refinanciamiento,*/
        pr_oficina,
        pr_monto_solicitado
        )

        SELECT  
        cod,
        INSTITUCION,
        id_cliente,
        NVL(CL_NOMBRE_COMPLETO, CL_NOMBRE_JURIDICO),
        'COTIZACIÓN',
        concat(concat(tp_codigo_prestamo,'0'),COD),
        SYSDATE, --PENDEINTE**
        fecha_inicio,
        --FECHA FIN PENDIENTE **
        tipo_prestamo,
        --tabla
        tp_tipo_calculo,
        tp_segmento, 
        tp_clase_prestamo,
        tp_base_calculo, 
        tp_paga_diciembre, 
        tp_cuota_fija, 
        tp_pagos_dia_fijo,
        extract(day from (fecha_inicio + dias_base)),--tp_dia_fijo, --
        --tabla
        TP_DIAS_PRIMER_PAGO,     --to_date(fecha_inicio, 'MM/DD/YYYY') - trunc(sysdate), --pendiente FECHA DEL SISTEMA
        FRECUENCIA,  --tp_frecuencia_cuota, 
        PLAZO_BASE,   -- tp_plazo_base, 
        tp_dias_gracia_mora_cuota, 
        tp_evitar_feriados_cuota, 
        tp_periodos_capital, 
        tp_periodos_interes,
        tp_cuota_completa, 
        fp_permite_pagos_extraordinarios, 
        tp_pago_adelantado_extraordinario,
        tp_disminuye_cuota_plazo,
        tp_paga_cuota_cargos,
        tp_interes_acumulado_proyectado,
        --end tabla
        monto_base,
        CT_VALOR_DEFECTO,
        cuota_base_user, --cuota user default 0 y luego lo que el cliente ingrese
        oficina, --of_num_oficina,
        monto_base

        FROM pr_tipo_prestamo, PR_CLIENTE , pr_tprestamo  C, 
        ---pr_oficina 
         PR_CARGO_TOPERACION--- C DE CABECERA
        WHERE tp_id_tprestamo = tipo_prestamo
        AND  CL_ID  =  id_cliente
        AND C.tp_id = tipo_prestamo
        --and of_id_institucion = INSTITUCION
        and CT_TIPO_CARGO =  'INTERES'
        and CT_ID_TIPO_OPERACION =tipo_prestamo ;

    ELSIF FUNCION = 'U1' THEN  -- PRIMERA PAGINA COTIZACION
    
        update  PR_PRESTAMO
        SET pr_plazo = plazo_base,
            pr_monto = monto_base, 
            pr_fecha_inicio = fecha_inicio
          --  pr_dias_primer_pago = to_date(fecha_inicio, 'MM/DD/YYYY') - trunc(sysdate)
        WHERE PR_ID = COD; 

    ELSIF FUNCION = 'U2' THEN  -- AJUSTES ESPECIALES EDICION
         
        IF FRECUENCIA = 'DIARIO' then 
            dias_base := 1;
            elsif FRECUENCIA = 'MENSUAL' then 
                dias_base := 30;
                elsif FRECUENCIA = 'SEMESTRAL' then 
                    dias_base := 180;
                        elsif FRECUENCIA = 'ANUAL'  then
                            dias_base := 360;
        END if;

        select pr_fecha_primer_pago into fecha_primer_pago from pr_prestamo where PR_ID = COD;
        if fecha_primer_pago is not null then
                dia_fijo := extract(day from (fecha_primer_pago)); -- dia fijo
                dias_primer_pago :=  trunc(fecha_primer_pago) - fecha_inicio ;--to_date(fecha_inicio, 'MM/DD/YYYY');
        else 
            dia_fijo := extract(day from (fecha_inicio + dias_base)) ;
            dias_primer_pago := 0;
        end if;
        
    
        update  PR_PRESTAMO
        SET pr_plazo = plazo_base,
            pr_periodos_capital = Periodo_capital,
            pr_periodos_interes = Periodo_interes,
            pr_paga_diciembre = Paga_Diciembre,
            pr_cuota_fija = Cuota_Fija,
            pr_monto = monto_base, --monto_base, 
            pr_fecha_inicio = fecha_inicio,
           pr_dias_primer_pago = dias_primer_pago, --to_date(fecha_inicio, 'MM/DD/YYYY') - trunc(sysdate),
            pr_dia_fijo =  dia_fijo, --extract(day from (fecha_inicio + dias_base)) --tp_dia_fijo, --
            pr_cuota = cuota_base_user,
            pr_monto_solicitado = monto_solicitado_editado,
            pr_oficina = oficina,
            pr_PAGOS_DIA_FIJO = PAGOS_DIA_FIJO --nuevo 2022
            , PR_FRECUENCIA_CUOTA = FRECUENCIA
        WHERE PR_ID = COD; 

    END IF;
  
END;
