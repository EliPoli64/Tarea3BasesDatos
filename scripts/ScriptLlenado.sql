USE ServiciosDB;

INSERT INTO dbo.TipoMovConsumo (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Debito por lectura')
	, (2, 'Credito por ajuste')
	, (3, 'Debito por ajuste');

INSERT INTO dbo.TipoUsoPropiedad (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Habitacion')
	, (2, 'Comercial')
	, (3, 'Industrial')
	, (4, 'Lote baldio')
	, (5, 'Agricola');

INSERT INTO dbo.TipoAreaPropiedad (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Residencial')
	, (2, 'Agricola')
	, (3, 'Bosque')
	, (4, 'Zona industrial')
	, (5, 'Zona comercial');

INSERT INTO dbo.TipoUsuario(
	[ID]
	, [Nombre]
) VALUES
	(1, 'Administrador')
	, (2, 'Propietario');

INSERT INTO dbo.TipoAsociacion(
	[ID]
	, [Nombre]
) VALUES
	(1, 'Asociar')
	, (2, 'Desasociar');

INSERT INTO dbo.TipoMedioPago (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Efectivo')
	, (2, 'Tarjeta');

INSERT INTO dbo.CCPeriodoCobro (
	[ID]
	, [Nombre]
	, [QDividir]
) VALUES
	(1, 'Mensual', 1)
	, (2, 'Trimestral', 3)
	, (3, 'Semestral', 6)
	, (4, 'Anual', 12)
	, (5, 'Unico no recurrente', 1)
	, (6, 'Diario intereses moratorios', 30);

INSERT INTO dbo.TipoEvento (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Consulta propiedad')
	, (2, 'Consulta factura')
	, (3, 'Calculo moratorios')
	, (4, 'Pago factura')
	, (5, 'Generacion factura')
	, (6, 'Lectura medidor')
	, (7, 'Orden corte agua')
	, (8, 'Orden reconexion')
	, (9, 'Asociacion propiedad')
	, (10, 'Cambio valor propiedad')
	, (11, 'Error sistema')
	, (12, 'Login usuario')
	, (13, 'Logout usuario')
	, (14, 'Modificacion datos')
	, (15, 'Proceso masivo');