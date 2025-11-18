CREATE OR ALTER PROCEDURE dbo.XMLProcesarPropiedadCambioValor
    @inNumFinca VARCHAR(16),
    @inNuevoValor DECIMAL(18,2),
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 10;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Exito: Cambio de valor de propiedad procesado - Finca: ' + @inNumFinca;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Propiedad WHERE NumFinca = @inNumFinca)
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Propiedad no encontrada - Finca: ' + @inNumFinca;
        END;

        IF @outResultCode = 0 AND @inNuevoValor <= 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: Valor de propiedad inválido - Finca: ' + @inNumFinca;
        END;

        IF @outResultCode = 0
        BEGIN
            UPDATE dbo.Propiedad 
            SET ValorPropiedad = @inNuevoValor
            WHERE NumFinca = @inNumFinca;

            IF @@ROWCOUNT = 0
            BEGIN
                SET @outResultCode = 50012;
                SET @descripcionEvento = 'Error: No se realizaron cambios - Finca: ' + @inNumFinca;
            END;
        END;

        IF (@outResultCode != 0)
        BEGIN
            SET @tipoEvento = 11;
            ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            COMMIT TRANSACTION;
        END;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
            UserName,
            Number,
            State,
            Severity,
            Line,
            [Procedure],
            Message,
            DateTime
        ) VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        );

        DECLARE @descError VARCHAR(64) = 'Error inesperado al procesar cambio de valor de propiedad - Finca: ' + @inNumFinca;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descError,
            11;
    END CATCH;
    SET NOCOUNT OFF;
END;
GO
