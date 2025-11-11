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