CREATE OR ALTER PROCEDURE dbo.XMLProcesarPersonas
	@Xml            XML,
	@inUserName     VARCHAR(32),
	@inIP           VARCHAR(32),
	@outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento  VARCHAR(256);
    DECLARE @resultBitacora     INT;
    DECLARE @tipoEvento         INT = 2;
    DECLARE @BaseID             INT;
    SET @outResultCode          = 0;
    SET @descripcionEvento      = 'Éxito: Personas procesadas correctamente';

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de Personas está vacío';
            GOTO FinPersonas;
        END;

        IF @Xml.exist('/Personas/Persona') = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Persona> en el XML';
            GOTO FinPersonas;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Xml.nodes('/Personas/Persona') AS T(P)
            JOIN dbo.Propietario AS PR ON PR.ValorDocumentoId = P.value('@valorDocumento', 'VARCHAR(32)'))	
        BEGIN
            SET @outResultCode = 50005; -- ID duplicada
            SET @descripcionEvento = 'Error: Ya existe al menos un propietario con el mismo documento';
            GOTO FinPersonas;
        END;
		
        BEGIN TRAN;
        SELECT  @BaseID = ISNULL(MAX(ID), 0)
        FROM    dbo.Propietario;
        ;WITH PersonasXml AS (
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS RowNum,
                P.value('@valorDocumento', 'VARCHAR(32)') AS ValorDocumento,
                P.value('@nombre', 'VARCHAR(64)') AS Nombre,
                P.value('@telefono', 'VARCHAR(16)') AS Telefono
            FROM @Xml.nodes('/Personas/Persona') AS T(P)
        )
		
        INSERT INTO dbo.Propietario (
            ID,
            Nombre,
            ValorDocumentoId,
            Telefono)
        SELECT
            @BaseID + PX.RowNum,
            PX.Nombre,
            PX.ValorDocumento,
            PX.Telefono
        FROM PersonasXml AS PX;
        COMMIT TRAN;

FinPersonas:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;  -- error
        END;

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

        INSERT INTO dbo.DBError(
            [UserName],
            [Number],
            [State],
            [Severity],
            [Line],
            [Procedure],
            [Message],
            [DateTime])
        VALUES(
			SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE());
    END CATCH;

    SET NOCOUNT OFF;
END;
