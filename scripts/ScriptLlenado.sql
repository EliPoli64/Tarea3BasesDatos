DECLARE @xml XML;

SELECT @xml = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Elias\projs\Tarea3BasesDatos\XMLs\CatalogosP3.xml', SINGLE_BLOB) AS x;

INSERT INTO dbo.TipoMovConsumo (
	[ID]
	, [Nombre]
)
SELECT 
	TipoMov.value('@id', 'INT'),
	TipoMov.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMovimientoLecturaMedidor/TipoMov') AS T(TipoMov);

INSERT INTO dbo.TipoUsoPropiedad (
	[ID]
	, [Nombre]
)
SELECT 
	TipoUso.value('@id', 'INT'),
	TipoUso.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoUsoPropiedad/TipoUso') AS T(TipoUso);

INSERT INTO dbo.TipoAreaPropiedad (
	[ID]
	, [Nombre]
)
SELECT 
	TipoZona.value('@id', 'INT'),
	TipoZona.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoZonaPropiedad/TipoZona') AS T(TipoZona);

INSERT INTO dbo.TipoUsuario(
	[ID]
	, [Nombre]
)
SELECT 
	TipoUser.value('@id', 'INT'),
	TipoUser.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoUsuario/TipoUser') AS T(TipoUser);

INSERT INTO dbo.TipoAsociacion(
	[ID]
	, [Nombre]
)
SELECT 
	TipoAso.value('@id', 'INT'),
	TipoAso.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoAsociacion/TipoAso') AS T(TipoAso);

INSERT INTO dbo.TipoMedioPago (
	[ID]
	, [Nombre]
)
SELECT 
	MedioPago.value('@id', 'INT'),
	MedioPago.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMedioPago/MedioPago') AS T(MedioPago);

INSERT INTO dbo.CCPeriodoCobro (
	[ID]
	, [Nombre]
	, [QDividir]
)
SELECT 
	PeriodoMonto.value('@id', 'INT'),
	PeriodoMonto.value('@nombre', 'VARCHAR(32)'),
	COALESCE(PeriodoMonto.value('@dias', 'INT'), PeriodoMonto.value('@qMeses', 'INT'))
FROM @xml.nodes('/Catalogos/PeriodoMontoCC/PeriodoMonto') AS T(PeriodoMonto);

INSERT INTO dbo.CCTipoMonto (
	[ID]
	, [Nombre]
)
SELECT 
	TipoMonto.value('@id', 'INT'),
	TipoMonto.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMontoCC/TipoMonto') AS T(TipoMonto);

INSERT INTO dbo.ConceptoCobro (
	[ID]
	, [Nombre]
	, [Activo]
)
SELECT 
	CC.value('@id', 'INT'),
	CC.value('@nombre', 'VARCHAR(32)'),
	1
FROM @xml.nodes('/Catalogos/CCs/CC') AS T(CC);

INSERT INTO dbo.CCTarifa (
	[ID]
	, [IDCC]
	, [IDPeriodoCobro]
	, [IDTipoMonto]
	, [VigenciaDesde]
	, [VigenciaHasta]
)
SELECT 
	CC.value('@id', 'INT'),
	CC.value('@id', 'INT'),
	CC.value('@PeriodoMontoCC', 'INT'),
	CC.value('@TipoMontoCC', 'INT'),
	'2022-01-01',
	'2099-12-31'
FROM @xml.nodes('/Catalogos/CCs/CC') AS T(CC);

INSERT INTO dbo.CCAgua (
	[ID]
	, [IDTarifa]
	, [CostoM3]
	, [M3TarifaMinima]
	, [M3Minimo]
	, [IncluyeBase]
)
SELECT 
	1,
	1,
	CC.value('@ValorFijoM3Adicional', 'MONEY'),
	CC.value('@ValorMinimoM3', 'MONEY'),
	CC.value('@ValorMinimo', 'MONEY'),
	1
FROM @xml.nodes('/Catalogos/CCs/CC[@id=1]') AS T(CC);

INSERT INTO dbo.CCTarifaFija (
	[ID]
	, [IDTarifa]
	, [Monto]
)
SELECT 
	CC.value('@id', 'INT'),
	CC.value('@id', 'INT'),
	CC.value('@ValorFijo', 'MONEY')
FROM @xml.nodes('/Catalogos/CCs/CC') AS T(CC)
WHERE CC.value('@TipoMontoCC', 'INT') = 1 
AND CC.value('@ValorFijo', 'VARCHAR(32)') != '';

INSERT INTO dbo.CCTarifaPorcentual (
	[ID]
	, [IDTarifa]
	, [Porcentaje]
	, [IDBaseCalculo]
)
SELECT 
	CC.value('@id', 'INT'),
	CC.value('@id', 'INT'),
	CC.value('@ValorPorcentual', 'DECIMAL(18,4)'),
	CASE 
		WHEN CC.value('@id', 'INT') = 3 THEN 1
		WHEN CC.value('@id', 'INT') = 7 THEN 4
		ELSE 1
	END
FROM @xml.nodes('/Catalogos/CCs/CC') AS T(CC)
WHERE CC.value('@TipoMontoCC', 'INT') = 3 
AND CC.value('@ValorPorcentual', 'VARCHAR(32)') != '';