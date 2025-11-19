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

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
		DECLARE @ErrorState INT = ERROR_STATE();
		DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
		DECLARE @ErrorLine INT = ERROR_LINE();
		DECLARE @ErrorProcedure VARCHAR(32) = ERROR_PROCEDURE();
		DECLARE @ErrorMessage VARCHAR(512) = ERROR_MESSAGE();
		DECLARE @UserName VARCHAR(32) = SUSER_SNAME();
		DECLARE @CurrentDate DATETIME = GETDATE();

		EXEC dbo.InsertarError
			@inSUSER_SNAME      = @UserName,
			@inERROR_NUMBER     = @ErrorNumber,
			@inERROR_STATE      = @ErrorState,
			@inERROR_SEVERITY   = @ErrorSeverity,
			@inERROR_LINE       = @ErrorLine,
			@inERROR_PROCEDURE  = @ErrorProcedure,
			@inERROR_MESSAGE    = @ErrorMessage,
			@inGETDATE          = @CurrentDate;

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
