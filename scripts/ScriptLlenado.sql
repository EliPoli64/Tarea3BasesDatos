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

INSERT INTO dbo.ConceptoCobro (
	[ID]
	, [Nombre]
	, [Activo]
) VALUES
	(1, 'Consumo Agua', 1)
	, (2, 'Impuesto a propiedad', 1)
	, (3, 'Recoleccion Basura', 1)
	, (4, 'Patente Comercial', 1)
	, (5, 'Reconexion', 1)
	, (6, 'Intereses Moratorios', 1)
	, (7, 'Mantenimiento Parques', 1);

INSERT INTO dbo.CCTipoMonto (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Monto Fijo')
	, (2, 'Monto Variable')
	, (3, 'Monto Porcentual');

INSERT INTO dbo.CCBaseCalculo (
	[ID]
	, [Nombre]
) VALUES
	(1, 'Valor propiedad')
	, (2, 'Area propiedad')
	, (3, 'Consumo agua')
	, (4, 'Monto factura');

INSERT INTO dbo.CCTarifa (
	[ID]
	, [IDCC]
	, [IDPeriodoCobro]
	, [IDTipoMonto]
	, [VigenciaDesde]
	, [VigenciaHasta]
) VALUES
	(1, 1, 1, 2, '2022-01-01', '2099-12-31')
	, (2, 2, 4, 3, '2022-01-01', '2099-12-31')
	, (3, 3, 1, 1, '2022-01-01', '2099-12-31')
	, (4, 4, 3, 1, '2022-01-01', '2099-12-31')
	, (5, 5, 5, 1, '2022-01-01', '2099-12-31')
	, (6, 6, 6, 3, '2022-01-01', '2099-12-31')
	, (7, 7, 4, 1, '2022-01-01', '2099-12-31');

INSERT INTO dbo.CCAgua (
	[ID]
	, [IDTarifa]
	, [CostoM3]
	, [M3TarifaMinima]
	, [M3Minimo]
	, [IncluyeBase]
) VALUES
	(1, 1, 1000.00, 30.00, 5000.00, 1);

INSERT INTO dbo.CCTarifaFija (
	[ID]
	, [IDTarifa]
	, [Monto]
) VALUES
	(3, 3, 150.00)
	, (4, 4, 25000.00)
	, (5, 5, 30000.00)
	, (7, 7, 2000.00);

INSERT INTO dbo.CCTarifaPorcentual (
	[ID]
	, [IDTarifa]
	, [Porcentaje]
	, [IDBaseCalculo]
) VALUES
	(2, 2, 0.01, 1)
	, (6, 6, 0.04, 4);