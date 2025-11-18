USE ServiciosDB;

INSERT INTO dbo.Usuario (
	[ID]
	, UserName
	, [Password]
	, EsActivo
	, IDTipo
) VALUES
	(1, 'elipoli', '12341234', 1, 1);

DECLARE @xml XML;

SELECT @xml = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Elias\projs\Tarea3BasesDatos\XMLs\CatalogosP3.xml', SINGLE_BLOB) AS x;

INSERT INTO dbo.TipoMovConsumo (
	[ID]
	, [Nombre]
)
SELECT 
	TipoMov.value('@id', 'INT')
	, TipoMov.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMovimientoLecturaMedidor/TipoMov') AS T(TipoMov);

INSERT INTO dbo.TipoUsoPropiedad (
	[ID]
	, [Nombre]
)
SELECT 
	TipoUso.value('@id', 'INT')
	, TipoUso.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoUsoPropiedad/TipoUso') AS T(TipoUso);

INSERT INTO dbo.TipoAreaPropiedad (
	[ID]
	, [Nombre]
)
SELECT 
	TipoZona.value('@id', 'INT')
	, TipoZona.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoZonaPropiedad/TipoZona') AS T(TipoZona);

INSERT INTO dbo.TipoUsuario (
	[ID]
	, [Nombre]
)
SELECT 
	TipoUser.value('@id', 'INT')
	, TipoUser.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoUsuario/TipoUser') AS T(TipoUser);

INSERT INTO dbo.TipoAsociacion (
	[ID]
	, [Nombre]
)
SELECT 
	TipoAso.value('@id', 'INT')
	, TipoAso.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoAsociacion/TipoAso') AS T(TipoAso);

INSERT INTO dbo.TipoMedioPago (
	[ID]
	, [Nombre]
)
SELECT 
	MedioPago.value('@id', 'INT')
	, MedioPago.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMedioPago/MedioPago') AS T(MedioPago);

INSERT INTO dbo.CCPeriodoCobro (
	[ID]
	, [Nombre]
	, [QDividir]
)
SELECT 
	PeriodoMonto.value('@id', 'INT')
	, PeriodoMonto.value('@nombre', 'VARCHAR(32)')
	, COALESCE(PeriodoMonto.value('@dias', 'INT'), PeriodoMonto.value('@qMeses', 'INT'))
FROM @xml.nodes('/Catalogos/PeriodoMontoCC/PeriodoMonto') AS T(PeriodoMonto);

INSERT INTO dbo.CCTipoMonto (
	[ID]
	, [Nombre]
)
SELECT 
	TipoMonto.value('@id', 'INT')
	, TipoMonto.value('@nombre', 'VARCHAR(32)')
FROM @xml.nodes('/Catalogos/TipoMontoCC/TipoMonto') AS T(TipoMonto);

INSERT INTO dbo.ConceptoCobro (
	[ID]
	, [Nombre]
	, [Activo]
)
SELECT 
	CC.value('@id', 'INT')
	, CC.value('@nombre', 'VARCHAR(32)')
	, 1
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
	CC.value('@id', 'INT')
	, CC.value('@id', 'INT')
	, CC.value('@PeriodoMontoCC', 'INT')
	, CC.value('@TipoMontoCC', 'INT')
	, '2022-01-01'
	, '2099-12-31'
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
	1
	, 1
	, CC.value('@ValorFijoM3Adicional', 'MONEY')
	, CC.value('@ValorMinimoM3', 'MONEY')
	, CC.value('@ValorMinimo', 'MONEY')
	, 1
FROM @xml.nodes('/Catalogos/CCs/CC[@id=1]') AS T(CC);

INSERT INTO dbo.CCTarifaFija (
	[ID]
	, [IDTarifa]
	, [Monto]
)
SELECT 
	CC.value('@id', 'INT')
	, CC.value('@id', 'INT')
	, CC.value('@ValorFijo', 'MONEY')
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
	CC.value('@id', 'INT')
	, CC.value('@id', 'INT')
	, CC.value('@ValorPorcentual', 'DECIMAL(18,4)')
	, CASE 
		WHEN CC.value('@id', 'INT') = 3 THEN 1
		WHEN CC.value('@id', 'INT') = 7 THEN 4
		ELSE 1
	  END
FROM @xml.nodes('/Catalogos/CCs/CC') AS T(CC)
WHERE CC.value('@TipoMontoCC', 'INT') = 3 
AND CC.value('@ValorPorcentual', 'VARCHAR(32)') != '';


DECLARE @OperacionesXml XML;

SELECT @OperacionesXml = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Elias\projs\Tarea3BasesDatos\XMLs\operaciones_limpio.xml', SINGLE_BLOB) AS x;

DECLARE @inUserName VARCHAR(32) = 'admin';
DECLARE @inIP VARCHAR(32) = '127.0.0.1';
DECLARE @outResultCode INT;

DECLARE @FechasOperacion TABLE (
	ID INT IDENTITY(1,1)
	, Fecha DATE
	, PersonasXml XML
	, PropiedadesXml XML
	, PropiedadPersonaXml XML
	, CCPropiedadXml XML
	, LecturasMedidorXml XML
	, PagosXml XML
);

INSERT INTO @FechasOperacion (
	Fecha
	, PersonasXml
	, PropiedadesXml
	, PropiedadPersonaXml
	, CCPropiedadXml
	, LecturasMedidorXml
	, PagosXml
)
SELECT
	T.FechaOperacion.value('@fecha', 'DATE')
	, T.FechaOperacion.query('./Personas')
	, T.FechaOperacion.query('./Propiedades')
	, T.FechaOperacion.query('./PropiedadPersona')
	, T.FechaOperacion.query('./CCPropiedad')
	, T.FechaOperacion.query('./LecturasMedidor')
	, T.FechaOperacion.query('./Pagos')
FROM @OperacionesXml.nodes('/Operaciones/FechaOperacion') AS T(FechaOperacion);

DECLARE @Contador INT = 1;
DECLARE @TotalFechas INT = (SELECT COUNT(*) FROM @FechasOperacion);
DECLARE @FechaOperacion DATE;
WHILE @Contador <= @TotalFechas
BEGIN
	SELECT 
		@FechaOperacion = Fecha
	FROM @FechasOperacion
	WHERE ID = @Contador;

	DECLARE @PersonasXml XML = (SELECT PersonasXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @PersonasXml IS NOT NULL AND @PersonasXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarPersonas
			@Xml = @PersonasXml
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0)
		BEGIN
			SELECT @outResultCode, @inUserName, @inIP;
			RETURN;
		END;
	END;

	DECLARE @PropiedadesXml XML = (SELECT PropiedadesXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @PropiedadesXml IS NOT NULL AND @PropiedadesXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarPropiedades
			@Xml = @PropiedadesXml
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0)
		BEGIN
            SELECT @outResultCode, 'Propiedades';
			RETURN;
		END;
	END;

	DECLARE @PropiedadPersonaXml XML = (SELECT PropiedadPersonaXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @PropiedadPersonaXml IS NOT NULL AND @PropiedadPersonaXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarPropiedadPersona
			@Xml = @PropiedadPersonaXml
			, @FechaOperacion = @FechaOperacion
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0)
		BEGIN
            SELECT @outResultCode, 'PropPersona';
			RETURN;
		END;
	END;

	DECLARE @CCPropiedadXml XML = (SELECT CCPropiedadXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @CCPropiedadXml IS NOT NULL AND @CCPropiedadXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarCCPropiedad
			@Xml = @CCPropiedadXml
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0)
		BEGIN
            SELECT @outResultCode, 'CCProp';
			RETURN;
		END;
	END;

	DECLARE @LecturasMedidorXml XML = (SELECT LecturasMedidorXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @LecturasMedidorXml IS NOT NULL AND @LecturasMedidorXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarLecturasMedidor
			@Xml = @LecturasMedidorXml
			, @FechaOperacion = @FechaOperacion
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0)
		BEGIN
            SELECT @outResultCode, 'Lecturas';
			RETURN;
		END;
	END;

	DECLARE @PagosXml XML = (SELECT PagosXml FROM @FechasOperacion WHERE ID = @Contador);
	IF @PagosXml IS NOT NULL AND @PagosXml.exist('*') = 1
	BEGIN
		EXEC dbo.XMLProcesarPagos
			@Xml = @PagosXml
			, @FechaOperacion = @FechaOperacion
			, @inUserName = @inUserName
			, @inIP = @inIP
			, @outResultCode = @outResultCode OUTPUT;
		IF (@outResultCode != 0 AND @outResultCode != 50009)
		BEGIN
            SELECT @outResultCode, 'Pagos';
			RETURN;
		END;
	END;

	SET @Contador = @Contador + 1;
END;
