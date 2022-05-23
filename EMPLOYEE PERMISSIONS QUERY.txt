--CONSULTA TX POR ROL

select
'Cod. Rol' = ta_rol,
'Rol' = substring(ro_descripcion, 1, 80),
'Transacci½n' = ta_transaccion,
'Descripci½nTransacci½n' = tn_descripcion,
'Producto' = ta_producto,
'Nombre Producto' = (select pd_descripcion from cobis..cl_producto where pd_producto = ta.ta_producto),
'Estado TX' = ta_estado,
'Estado ROL' = ro_estado 
from cobis..ad_tr_autorizada ta,
cobis..ad_rol,
cobis..cl_ttransaccion
where ro_rol = ta_rol
and tn_trn_code = ta_transaccion
--and tn_descripcion like '%Devoluci%'
and tn_trn_code	= 3040
--and ta_estado = 'V'
--and ro_estado = 'V'

--BUSQUEDA TRANSACCIONES POR NOMBRE

select * from cobis..cl_ttransaccion
where tn_descripcion like '%DORMIDA%'