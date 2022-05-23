use cob_cuentas

select top 100 * from cc_ctacte
where cc_estado='B'
and cc_saldo_ayer=0
and substring (cc_cta_banco,1,2)='25'


select * from cc_estado_cta

select distinct cc_estado from cc_ctacte
where cc_estado='B'



sp_helptext  estado 

select * from cobis..cl_tabla
where tabla like  '%estado%'

select * from cobis..cl_catalogo
where tabla = 107


select top 100 cc_cta_banco, cb.* from cc_ctabloqueada cb
inner join cc_ctacte
  on cb_cuenta = cc_ctacte
where cb_estado = 'L'
and cb_fecha >= '01/01/2021'