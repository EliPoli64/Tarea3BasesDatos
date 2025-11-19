CREATE OR ALTER PROCEDURE dbo.XMLProcesarPropiedadCambioValor
    @Xml XML,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @descripcionEvento VARCHAR(256) ;
    DECLARE @resultBitacora INT ;
    DECLARE @tipoEvento INT = 2 ;

    SET @outResultCode = 0 ;
    SET @descripcionEvento = 'Éxito: Cambios de valor de propiedades procesados correctamente' ;

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002 ;
            SET @descripcionEvento = 'Error: XML de PropiedadCambioValor vacío' ;
            GOTO FinCambioValor ;
        END ;

        IF @Xml.exist('/PropiedadCambio/Cambio') = 0
        BEGIN
            SET @outResultCode = 50012 ;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Cambio> en PropiedadCambioValor' ;
            GOTO FinCambioValor ;
        END ;

        -- Tabla temporal para almacenar los cambios
        DECLARE @Cambios TABLE
        (
            NumFinca VARCHAR(16),
            NuevoValor DECIMAL(18,2),
            IDPropiedad INT
        ) ;

        -- Extraer datos del XML con la estructura correcta
        INSERT INTO @Cambios
        (
            NumFinca,
            NuevoValor,
            IDPropiedad
        )
        SELECT
            C.value('@numeroFinca', 'VARCHAR(16)') AS NumFinca,
            C.value('@nuevoValor', 'DECIMAL(18,2)') AS NuevoValor,
            P.ID AS IDPropiedad
        FROM @Xml.nodes('/PropiedadCambio/Cambio') AS T(C)
        LEFT JOIN dbo.Propiedad AS P
            ON P.NumFinca = C.value('@numeroFinca','VARCHAR(16)');

        -- Validar que no haya valores <= 0
        IF EXISTS (
            SELECT 1
            FROM @Cambios
            WHERE NuevoValor <= 0
        )
        BEGIN
            SET @outResultCode = 50002 ;
            SET @descripcionEvento = 'Error: Al menos un nuevo valor fiscal es inválido (<= 0)' ;
            GOTO FinCambioValor;
        END ;

        -- Validar que todas las fincas existan
        IF EXISTS (
            SELECT 1
            FROM @Cambios
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Al menos una finca de PropiedadCambioValor no existe';
            GOTO FinCambioValor ;
        END;

        BEGIN TRAN;

        UPDATE P
        SET P.ValorPropiedad = C.NuevoValor
        FROM dbo.Propiedad P
        INNER JOIN @Cambios C ON P.ID = C.IDPropiedad
        WHERE P.ValorPropiedad <> C.NuevoValor; -- Solo actualizar si el valor realmente cambió

        IF @@ROWCOUNT = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No se actualizó ningún valor de propiedad (los valores ya estaban actualizados)' ;
            ROLLBACK TRAN;
            GOTO FinCambioValor;
        END;

        COMMIT TRAN;

FinCambioValor:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;
        END ;

        EXEC dbo.InsertarBitacora
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRAN;
        END;

        SET @outResultCode = 50008;

        INSERT INTO dbo.DBError
        (
            [UserName],
            [Number],
            [State],
            [Severity],
            [Line],
            [Procedure],
            [Message],
            [DateTime]
        )
        VALUES
        (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        ) ;

        DECLARE @descError VARCHAR(256) = 'Error inesperado al procesar cambio de valor de propiedad' ;

        EXEC dbo.InsertarBitacora
            @inIP,
            @inUserName,
            @descError,
            11;
    END CATCH;

    SET NOCOUNT OFF;
END ;
GO