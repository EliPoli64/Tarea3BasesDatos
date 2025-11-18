CREATE OR ALTER PROCEDURE dbo.XMLProcesarPropiedadCambioValor
    @Xml XML,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON ;

    DECLARE @descripcionEvento VARCHAR(256) ;
    DECLARE @resultBitacora INT ;
    DECLARE @tipoEvento INT = 2 ;

    SET @outResultCode = 0 ;
    SET @descripcionEvento = 'Éxito: Cambios de valor de propiedades procesados correctamente' ;

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002 ;  -- Validación fallida
            SET @descripcionEvento = 'Error: XML de PropiedadCambioValor vacío' ;
            GOTO FinCambioValor ;
        END ;

        IF @Xml.exist('/PropiedadCambioValor/Cambio') = 0
        BEGIN
            SET @outResultCode = 50012 ;  -- Sin cambios
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Cambio> en PropiedadCambioValor' ;
            GOTO FinCambioValor ;
        END ;

        DECLARE @Cambios TABLE
        (
            NumFinca VARCHAR(16),
            NuevoValor DECIMAL(18,2),
            IDPropiedad INT
        ) ;

        INSERT INTO @Cambios
        (
            NumFinca,
            NuevoValor,
            IDPropiedad
        )
        SELECT
            C.value('@numeroFinca', 'VARCHAR(16)')  AS NumFinca,
            C.value('@nuevoValorFiscal','DECIMAL(18,2)') AS NuevoValor,
            P.ID                                         AS IDPropiedad
        FROM @Xml.nodes('/PropiedadCambioValor/Cambio') AS T(C)
        LEFT JOIN dbo.Propiedad AS P
            ON P.NumFinca = C.value('@numeroFinca','VARCHAR(16)');

        -- Valor <= 0
        IF EXISTS (
            SELECT 1
            FROM @Cambios
            WHERE NuevoValor <= 0
        )
        BEGIN
            SET @outResultCode = 50002 ;  -- Validación fallida
            SET @descripcionEvento = 'Error: Al menos un nuevo valor fiscal es inválido (<= 0)' ;
            GOTO FinCambioValor;
        END ;

        -- Propiedad no encontrada
        IF EXISTS (
            SELECT 1
            FROM @Cambios
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;  -- No encontrado
            SET @descripcionEvento = 'Error: Al menos una finca de PropiedadCambioValor no existe';
            GOTO FinCambioValor ;
        END;

        BEGIN TRAN;

        UPDATE P
        SET  P.ValorPropiedad = C.NuevoValor
        FROM dbo.Propiedad AS P
        JOIN @Cambios AS C
            ON P.ID = C.IDPropiedad;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @outResultCode = 50012;  -- Sin cambios
            SET @descripcionEvento = 'Sin cambios: No se actualizó ningún valor de propiedad' ;
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

        SET @outResultCode = 50008;  -- ErrorBD

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
