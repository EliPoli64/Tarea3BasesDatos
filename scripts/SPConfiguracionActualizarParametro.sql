CREATE OR ALTER PROCEDURE dbo.ConfiguracionActualizarParametro
    @inNombre           VARCHAR(64)
    , @inValor          VARCHAR(64)
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM ParametrosSistema WHERE Nombre = @inNombre)
        BEGIN
            UPDATE ParametrosSistema 
            SET Valor = @inValor 
            WHERE Nombre = @inNombre;
        END
        ELSE
        BEGIN
            INSERT INTO ParametrosSistema (Nombre, Valor)
            VALUES (@inNombre, @inValor);
        END
        DECLARE @descBitacora VARCHAR(128) = 'Parámetro actualizado: ' + @inNombre + ' = ' + @inValor;
        EXEC dbo.InsertarBitacora
            @inIP
            , @inUserName
            , @descBitacora
            , 2;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
			[UserName]
			, [Number]
			, [State]
			, [Severity]
			, [Line]
			, [Procedure]
			, [Message]
			, [DateTime]
		) VALUES (
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
		);
    END CATCH;
END;
GO