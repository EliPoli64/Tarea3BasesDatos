CREATE OR ALTER PROCEDURE dbo.ConfiguracionObtenerParametros
    @inUserName         VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT ID, Nombre, Valor 
        FROM ParametrosSistema
        ORDER BY Nombre;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Consulta de parámetros del sistema'
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



