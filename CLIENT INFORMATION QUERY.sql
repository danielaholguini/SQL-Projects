select
'TOPER'   = op_toperacion, 
'COD_SIB' = tr_finalidad, 
'DES_SIB' = (select valor from cobis..cl_catalogo where tabla = 505 and codigo = T.tr_finalidad),
'COD_TWB' = tr_utilizacion,
'DES_TWB' = (select valor from cobis..cl_catalogo where tabla = 587 and codigo = T.tr_utilizacion),
'CANTIDAD' = count(1),
'ACT_MIS' = (select valor from cobis..cl_catalogo where tabla = 1 and codigo = C.en_actividad)
from cob_credito..cr_tramite T, cob_cartera..ca_operacion, cobis..cl_ente C
where tr_tramite = op_tramite
and op_estado = 1
and op_toperacion = 'PAG-PPER'
and en_ente = tr_cliente
group by op_toperacion, tr_finalidad, tr_utilizacion, en_actividad