CREATE OR ALTER PROCEDURE dbo.ConfiguracionCambiarEstadoUsuario
    @inIDUsuario        INT
    , @inNuevoEstado    BIT
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        UPDATE Usuario 
        SET EsActivo = @inNuevoEstado 
        WHERE ID = @inIDUsuario;
        
        DECLARE @estadoTexto VARCHAR(20) = CASE WHEN @inNuevoEstado = 1 THEN 'activado' ELSE 'desactivado' END;
        DECLARE @descBitacora VARCHAR(128) = 'Usuario ' + CAST(@inIDUsuario AS VARCHAR) + ' ' + @estadoTexto;
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