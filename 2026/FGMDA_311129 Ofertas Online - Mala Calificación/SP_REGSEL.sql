create or replace PROCEDURE SP_REGSEL
            (
              P_ppcod NUMBER --Empresa
            , P_PEPAIS NUMBER --País del cliente
            , P_PETDOC NUMBER --tipo de documento del cliente
            , P_NRODOC VARCHAR --número de documento del cliente
            , P_CTNRO NUMBER --Cuenta Cliente
            , P_Vigente NUMBER --Es vigente el cliente ? 1:SI 0:NO
            , P_Z663CORR NUMBER --Código de Pre-evaluación.
            , P_F012FLAG_VAL OUT NUMBER --Código de validación controlado.
            , P_INDOPE OUT VARCHAR -- Cod. Error SQL
            , P_SQLERRM OUT VARCHAR -- MsjVal Error SQL
            )
IS
-- ================================================================================================================================
-- SVT 4315 - SQUAD RIESGOS
-- Tabla: SP_REGSEL - VALIDAR DATOS DEL CLIENTE.
-- Descripción: VALIDAR DATOS DEL CLIENTE ANTES DE TOMAR DATOS DE LA OFERTA ONLINE
-- Creacion: 06-10-22 - TJROC100
-- REQ:     FGMDA-xxxxx
--=================================================================================================================================
-- FECHA        REQUERIMENTO   MODIFICACION                                                            AUTOR
--=================================================================================================================================
-- 14/11/2022   FGMDA-xxxxx    AJUSTES DE REGLAS. (25)                                                 TJROC100
-- 21/11/2022   FGMDA-xxxxx    AJUSTES DE REGLAS. (3,4,5,6,7 y 19)                                     TJROC100
-- 08/03/2023   FGMDA-xxxxx    SE REALIZA AJUSTE A REGLAS 13, 14, 30                                   RYL - SVT 4552
-- 29/04/2024   FGMDA-121789   Ajuste Regla 33                                                         Externo Ses 33
-- 02/07/2025   FGMDA-242898   Se agrega flag para activacion de reglas.                               Ronal Yanqui Lopez
-- 06/02/2026   FGMDA-305353   Se actualiza puntos de corte de buró y comportamental de 75,55 a 58,51  Ronal Yanqui Lopez
--=================================================================================================================================

    P_Fecha_Ini DATE;
    P_Fecha_MesAntIni DATE;
    P_Fecha_MesAntFin DATE;
    P_Fecha_finmes_habil DATE;
    P_Pfpais NUMBER(3);
    P_Sucurs NUMBER(3);
    P_TrueData NUMBER(1);
    P_WFPAPEL NUMBER(4);
    P_pgfcie DATE;
    P_Exclu NUMBER(1);
    P_Fecha_Dia DATE;
    P_F012FLAG1 NUMBER(3,0);
    P_CTNROCOY NUMBER(9,0);
    P_PETDOCCOY NUMBER(2,0);
    P_PENDOCCOY CHAR(12 BYTE);
    P_PENDOC CHAR(12 BYTE);
    v_COTCBI FSH005.COTCBI%TYPE;
    V_REGLA NUMBER(5,0);
    V_GENERALOG  NUMBER(2,0); -- 20250702 RYL
    P_JCOL115HINI VARCHAR(8); -- 20250702 RYL
    P_JCOL115HFIN VARCHAR(8); -- 20250702 RYL
    V_FLGACTRLG NUMBER(9,0);  -- 20250702 RYL
BEGIN

    --INSTRUMENTACION
    FCINSTRIN ('Realiza la pre-evaluación del cliente','SP_REGSEL');

    -- Hora de inicio de ejecución                                      -- 20250702 RYL
    SELECT TO_CHAR(SYSDATE,'HH24:MI:SS') INTO P_JCOL115HINI  FROM DUAL; -- 20250702 RYL

    P_F012FLAG1 := 0;
    P_Sucurs    := 991; --Sucursal para calendario de cierre.
    P_CTNROCOY  := 0;
    P_PETDOCCOY := 0;
    P_PENDOCCOY := '';
    P_Pfpais    := P_PEPAIS;
    P_WFPAPEL   := 0;
    P_PENDOC    := P_NRODOC;
    V_REGLA     := 0;
    V_GENERALOG := 0;   -- 20250702 RYL
    V_FLGACTRLG := 0;   -- 20250702 RYL

  -- Verifica si debe generar log
    BEGIN
      SELECT TPIMP INTO V_GENERALOG
      FROM FST098 WHERE PGCOD = 1 AND TPCOD = 15567 AND TPCORR = 17;
    EXCEPTION
         WHEN NO_DATA_FOUND THEN
             V_GENERALOG := 0;
    END;

  -- Verifica si desactiva reglas
    BEGIN
      SELECT TPNRO INTO V_FLGACTRLG
      FROM FST098 WHERE PGCOD = 1 AND TPCOD = 81080;
    EXCEPTION
         WHEN NO_DATA_FOUND THEN
             V_FLGACTRLG := 0;
    END;

  --Tomo la fecha del día.
  SELECT PGFCIE INTO P_pgfcie FROM FST017 WHERE PGCOD = P_ppcod;

  --Inicializa la fecha de cierre y la seteo en la variable P_Fecha_Ini
  P_Fecha_Ini := TRUNC(P_pgfcie,'MM');

  P_Fecha_MesAntIni := ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-2);

  --Capturo mes &Fecha_finmes_habil
  SELECT MAX(FFECHA) INTO P_Fecha_finmes_habil FROM FST028
  WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
        AND FFECHA BETWEEN TRUNC(P_pgfcie, 'MM') AND TRUNC(LAST_DAY(P_pgfcie));

    IF P_pgfcie<P_Fecha_finmes_habil THEN
        SELECT MAX(FFECHA) INTO P_Fecha_finmes_habil FROM FST028
        WHERE FHABIL = 'S' AND CALCOD =  (SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
        AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_pgfcie,-1), 'MM') AND TRUNC(LAST_DAY(ADD_MONTHS(P_pgfcie,-1)));
    END IF;

   --Buscar el tipo de cambio.
   BEGIN
        SELECT COTCBI INTO v_COTCBI  FROM FSH005 WHERE MONEDA = 101 AND COFDES = P_pgfcie;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            P_SQLERRM := P_SQLERRM || 'No se pudo Obtener el Tipo de Cambio|';
        WHEN TOO_MANY_ROWS THEN
            P_SQLERRM := P_SQLERRM || 'Existe mas de un registro';
        WHEN OTHERS THEN
            P_SQLERRM := P_SQLERRM ||'Error al obtener el Tipo de Cambio';
    END;

    P_Fecha_MesAntFin := LAST_DAY(ADD_MONTHS((TRUNC(P_Fecha_finmes_habil,'MM')),-1));

    P_SQLERRM := P_SQLERRM || 'R0|';

    --Obtener la cuenta cliente del cónyuge.
    BEGIN
        WITH CTE_BASE AS
        (
        SELECT P_CTNRO AS ROW_ID
               ,P_PETDOC AS Petdoc
               ,P_PENDOC AS Pendoc
        FROM DUAL
        )
        ,CTE_CONY AS
        (
        SELECT ROW_ID,Rptdoc,Rpndoc
        FROM (
             SELECT ROW_ID
                    ,Rptdoc
                    ,Rpndoc
                    ,DENSE_RANK() OVER(PARTITION BY ROW_ID ORDER BY Rpndoc) AS ORDEN_ID
             FROM (
                    SELECT ROW_ID
                          ,NVL(A.Rptdoc,NVL(B.Rptdoc,'')) AS Rptdoc
                          ,NVL(A.Rpndoc,NVL(B.Rpndoc,'')) AS Rpndoc
                    FROM CTE_BASE
                    LEFT JOIN FSR002 A ON A.Pepais = P_Pfpais AND A.Petdoc = CTE_BASE.Petdoc AND A.Pendoc = CTE_BASE.Pendoc AND A.RPCCYG = 15
                    LEFT JOIN FSR002 B ON B.Rppais = P_Pfpais AND B.Rptdoc = CTE_BASE.Petdoc AND B.Rpndoc = CTE_BASE.Pendoc AND B.RPCCYG = 15
                )  B
            ) A
            WHERE ORDEN_ID = 1 --Evita duplicidad de llave para los clientes con más de un conyugue registrado.
        )SELECT Rptdoc,Rpndoc INTO P_PETDOCCOY,P_PENDOCCOY
         FROM CTE_CONY;

        EXCEPTION
             WHEN NO_DATA_FOUND THEN
                    P_PETDOCCOY := 0;
                    P_PENDOCCOY := '';
        END;

        IF P_PETDOCCOY <> 0 THEN
            BEGIN

                SELECT CTNRO INTO P_CTNROCOY
                FROM FSR008
                WHERE PGCOD = P_ppcod AND Pepais = P_Pfpais AND Petdoc = P_PETDOCCOY AND Pendoc = P_PENDOCCOY AND TTCOD = 1 AND CTTFIR = 'T'
                GROUP BY CTNRO
                HAVING COUNT(1) = 1;

                EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                         P_CTNROCOY := 0;
                END;
        END IF;
  IF V_FLGACTRLG = 1 THEN
      -----------------------------------------------------------------------
      --Regla 01 Tipo de documento DNI.
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 1;

            SELECT (CASE WHEN P_PETDOC = 21 THEN 0 ELSE 1 END) INTO P_F012FLAG1 FROM DUAL;
        END IF;

      -----------------------------------------------------------------------
      --Regla 02 Cliente debe tener la edad comprendida entre 21 a 70 años inclusive (Marca Clientes). Calculo entre fecha de nacimiento y fecha desembolso de la PO (población objetivo) y filtra
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 2;

            BEGIN
              SELECT 2 INTO P_F012FLAG1
              FROM FSD002 WHERE PFPAIS = P_PEPAIS AND PFTDOC = P_PETDOC AND PFNDOC = P_PENDOC
                            AND ROWNUM = 1 AND NOT ((FLOOR(months_between(P_pgfcie, FSD002.PFFNAC ))) BETWEEN 252 AND 840)
              ;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 03 Cliente no debe tener una antigüedad menor de 6 meses (Marca Antigüedad). Considera la fecha de desembolso mas antigua en los ultimo 48 meses y resta con fecha de analisis.
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 3;

            BEGIN
              SELECT 3 INTO P_F012FLAG1
              FROM (
                     SELECT (CASE WHEN (FLOOR ( MONTHS_BETWEEN ( TRUNC( P_pgfcie ), TRUNC ( MIN(AOFVAL) ) ))) < 6 THEN 1 ELSE 0 END) AS RGL03
                     FROM FSD010 WHERE PGCOD = P_ppcod
                                   AND AOCTA = P_CTNRO
                                   AND AOMOD IN (SELECT MODULO FROM FST111 WHERE DSCOD = 50)
                                   --AND AOFVAL >= ADD_MONTHS(P_pgfcie, -48)
                           ) A
                       WHERE ROWNUM = 1 AND RGL03 = 1
              ;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 04 Cliente no debe haber sido atendido por algún crédito Inclusión en los últimos 2 años (Marca Inclusión).--> Módulo 102 a excepción tipo_ope 123
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 4;

            BEGIN
              SELECT 4 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND (
                           (FSD010.AOFVAL >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT = 0)
                            OR (FSD010.AOFE99 >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT <> 0)
                           )
                      AND FSD010.AOMOD = 102
                      AND NOT (FSD010.AOTOPE = 123)
                      AND ROWNUM = 1
              ;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 05 Cliente no debe haber sido atendido por algún crédito Agro en los últimos 2 años (Marca Agro). -----> Módulo 101 a excepción tipo ope: 200, 150 y 112
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 5;

            BEGIN
              SELECT 5 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND (
                           (FSD010.AOFVAL >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT = 0)
                            OR (FSD010.AOFE99 >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT <> 0)
                           )
                      AND FSD010.AOMOD = 101
                      AND NOT (FSD010.AOTOPE IN (112,150,200))
                      AND ROWNUM = 1
              ;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 06 Clientes no debe haber sido atendido con Módulo 103 y proudcto Consumo en los últimos 2 años (Marca Consumo), a excepción tipo: 10, 11, 20, 30, 36, 60, 70, 80, 90, 100, 105, 136, 137,138, 200
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 6;

            BEGIN
              SELECT 6 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND (
                           (FSD010.AOFVAL >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT = 0)
                            OR (FSD010.AOFE99 >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT <> 0)
                           )
                      AND FSD010.AOMOD = 103
                      AND NOT (FSD010.AOTOPE IN (10, 11, 20, 30, 36, 60, 70, 80, 90, 100, 105, 136, 137,138, 200))
                      AND ROWNUM = 1
              ;

            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 07 Cliente no debe haber sido atendido con los siguientes Módulos 103 (tipo ope:10,11,60,70,20,80,100,105), 105, 106, 108, 109, 110, 115 de los últimos 2 años (Marca Otros)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 7;

            BEGIN
              SELECT 7 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND (
                           (FSD010.AOFVAL >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT = 0)
                            OR (FSD010.AOFE99 >= ADD_MONTHS((TRUNC(P_pgfcie,'MM')),-23) AND AOSTAT <> 0)
                           )
                      AND (AOMOD IN (105, 106, 108, 109, 110, 115)
                          OR (AOMOD = 103 AND AOTOPE IN (10,11,60,70,20,80,100,105)))
                      AND ROWNUM = 1
              ;

            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 08 A - Tit Cliente/ Cónyuge (si tuviese) no debe haber tenido ningún crédito castigado en su historial  (Marca Castigo).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 8;

            BEGIN
              SELECT 8 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND AOFVAL >= ADD_MONTHS(P_pgfcie, -23)
                      AND AOMOD = 33
                      AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 08 - B Cony Cliente/ Cónyuge (si tuviese) no debe haber tenido ningún crédito castigado en su historial  (Marca Castigo).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_CTNROCOY <> 0 THEN
            V_REGLA := 8;

            BEGIN
              SELECT 8 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNROCOY --Cónyuge
                      AND AOFVAL >= ADD_MONTHS(P_pgfcie, -23)
                      AND AOMOD = 33
                      AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 09 - Cliente no debe tener desembolso en el mes anterior, que su indicador cartera = vigente y sub ope = 0). Considerar desde el 1er dia del mes anterior hasta la fecha de proceso
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 9;

            BEGIN
              SELECT 9 INTO P_F012FLAG1
              FROM FSD010
              WHERE PGCOD = P_ppcod AND AOCTA = P_CTNRO
                      AND AOFVAL >= P_Fecha_MesAntIni
                      AND FSD010.AOMOD IN (SELECT MODULO FROM FST111 WHERE DSCOD = 50)
                      AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 10 --Regla negativa Cliente contactables según base
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 10;

            BEGIN
              SELECT 0 INTO P_F012FLAG1
              FROM JFCT491
              WHERE T491CHPU <> 0
                    AND T491TDOC = P_PETDOC
                    AND T491NDOC = P_PENDOC
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 10;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 11 - Cliente no debe ser diferente a Independiente con Negocio (Marca Independiente). Cruza Personas Fisicas con PO (población objetivo)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 11;

            BEGIN
              SELECT 0 INTO P_F012FLAG1
              FROM SNGC60
              INNER JOIN SNGC07 ON SNGC07.SNGC07COD = SNGC60.SNGC60Ocup
              WHERE SNGC60.SNGC60PAIS = P_Pfpais AND SNGC60.SNGC60TDOC = P_PETDOC AND SNGC60.SNGC60NDOC = P_PENDOC AND SNGC60CORR = 0
                    AND SNGC07.SEGCOD = 1 --Independiente
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 11;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 12 : Condonaciones - Cliente no debe tener condonaciones (Marca Condonación).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 12;

            BEGIN
              SELECT 12 INTO P_F012FLAG1
              FROM JNGZ673
              WHERE Z673CTNR = P_CTNRO
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 13 : Puntaje buroCliente debe tener puntaje mayor igual a 55.88 - Comp.(si el cliente no cumple para tener un puntaje, formará parte de los prospectos si cumple los criterios de selección) NOTA: Aquellos que no tienen puntaje se marca con "S"
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 13;

            BEGIN
              SELECT 13 INTO P_F012FLAG1
              FROM JNGZ663
              WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                    AND Z663BPT <= 58 AND Z663CPT = 999;    -- 06/02/2026 RYL
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

        ------------------------------------------------------------------------
      --Regla 14 : Cliente debe tener puntaje NO BURAL (COMPARTAMENTAL) mayor igual a 66.61 - Buro (si el cliente no cumple para tener un puntaje, formará parte de los prospectos si cumple los criterios de selección)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 14;

            BEGIN
              SELECT 14 INTO P_F012FLAG1
              FROM JNGZ663
              WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                    AND Z663CPT <= 51;    -- 06/02/2026 RYL
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

        ------------------------------------------------------------------------
      --Regla 15 A - TIT: Cliente/ Cónyuge (si estuviese) no deben encontrarse en la BD Lista Negra (Marca Cli LN).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 15;

            BEGIN
              SELECT 15 INTO P_F012FLAG1
              FROM FSD201
              WHERE FSD201.LNPAIS = P_Pfpais AND FSD201.LNTDOC = P_PETDOC AND FSD201.LNNDOC = P_PENDOC
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 15 B - COY: Cliente/ Cónyuge (si estuviese) no deben encontrarse en la BD Lista Negra (Marca Cli LN).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_PETDOCCOY <> 0 THEN
            V_REGLA := 15;

            BEGIN
              SELECT 15 INTO P_F012FLAG1
              FROM FSD201
              WHERE FSD201.LNPAIS = P_Pfpais AND FSD201.LNTDOC = P_PETDOCCOY AND FSD201.LNNDOC = P_PENDOCCOY
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 16 - No tener créditos reprogramados (covid / no covid) FC en el último mes (Marca Repro). - Cruza PO vs ultimo stock de reprogramados al cierre
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 16;

            BEGIN
              SELECT 16 INTO P_F012FLAG1
              FROM FSD011
              WHERE PGCOD = P_ppcod
                    AND FSD011.SCRUB IN (
                                           SELECT DISTINCT RUBRO FROM FSD014
                                           WHERE (RUBRO LIKE '81_933%' OR RUBRO LIKE '81_936%' OR RUBRO LIKE '81_937%' OR RUBRO LIKE '81_948%'  OR RUBRO LIKE '81_927%')
                                         )
                    AND FSD011.SCCTA = P_CTNRO
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 17: Creditos del Cony. - Cónyuges no deberán contar con un crédito en el último periodo (Marca Cred. Cyg). Ultima cartera
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_PETDOCCOY <> 0 THEN
            V_REGLA := 17;

            BEGIN
              SELECT 17 INTO P_F012FLAG1
              FROM  JNGY06
              WHERE --JNGY42.Y42FECPRO = P_Fecha_finmes_habil AND
                    Y06TIPDOC = P_PETDOCCOY AND Y06NUMDOC = P_PENDOCCOY
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 18: Cliente vigente no debe tener tipificación de crédito diferente a Pequeña y Micro Empresa (Marca Tipo de Crédito SBS)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 18;

            BEGIN
              SELECT 18 INTO P_F012FLAG1
              FROM (
                      SELECT SUM((CASE WHEN Y06CRESBS IN (9,10,12,13) THEN 0 ELSE 1 END)) AS TIPCRED
                      FROM  JNGY06
                      WHERE Y06CODEMP = P_ppcod
                            --AND Y42FECPRO = P_Fecha_finmes_habil
                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                    ) A
              WHERE TIPCRED <> 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 19 Nro de cred canc. - Clientes Vigentes debe tener ningún crédito Cancelado en su historia (Marca Cred_Can.). Ultima Cartera
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 19;

            BEGIN
                SELECT 19 INTO P_F012FLAG1
                FROM (
                      SELECT MAX(NVL(Y06NUMCRCLI,0)) AS NroCredTot
                      FROM JNGY06
                      WHERE Y06CODEMP = P_ppcod
                            --AND Y06FECPRO = P_Fecha_finmes_habil
                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                     ) A
                WHERE NroCredTot <= 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 20 El monto desembolsado del credito vigente no debe estar fuera del rango [300 – 30,000] Soles (Marca Desem).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 20;

            BEGIN
              SELECT 20 INTO P_F012FLAG1
                FROM (
                      SELECT SUM((CASE WHEN (Y06MONDES* (CASE WHEN Y06CODMOD = 101 THEN v_COTCBI ELSE 1.00 END)) BETWEEN 300 AND 30000 THEN 0 ELSE 1 END)) AS NroCredFueRan
                      FROM JNGY06
                      WHERE Y06CODEMP = P_ppcod
                            --AND Y06FECPRO = P_Fecha_finmes_habil
                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                     ) A
                WHERE NVL(NroCredFueRan,0) > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 21 Clientes vigentes no deben tener menor a 30% de cuotas pagadas (Marca % Cuo Pag.).--> [0 a 20%> y [20% a 30%], si cliente tiene mas de dos creditos se busca el maximo % cuotas pagadas
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 21;

            BEGIN
              SELECT 21 INTO P_F012FLAG1
              FROM (
                                SELECT ((Y06TOTCUO - Y06CUOPEN)/ Y06TOTCUO) AS PORCUOPAG
                                FROM JNGY06
                                WHERE Y06CODEMP = P_ppcod --AND JNGY42.Y42FECPRO = P_Fecha_finmes_habil
                                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                   ) A
               WHERE NVL(PORCUOPAG,0.00) < 0.3
                     AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 22 Cliente vigente no debe tener % de amortización en FC menor a 20% (el ultimos mes su saldo a la fecha vs Monto Desemb.)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 22;

            BEGIN
              SELECT 22 INTO P_F012FLAG1
              FROM (
                                SELECT ((Y06MONDES-Y06SALCAP) / Y06MONDES) AS PORSALCAP
                                FROM JNGY06
                                WHERE Y06CODEMP = P_ppcod --AND JNGY42.Y42FECPRO = P_Fecha_finmes_habil
                                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                   ) A
               WHERE NVL(PORSALCAP,0.00) < 0.2
                     AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;


      ------------------------------------------------------------------------
      --Regla 23 Cliente vigente no debe tener mora con más de 30 días de atraso al cierre (Marca Mora Actual >30d).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 23;

            BEGIN
              SELECT 23 INTO P_F012FLAG1
              FROM (
                                SELECT SUM((CASE WHEN  Y06DIAATR > 30 THEN 1 ELSE 0 END)) AS Y42DIAATR
                                FROM JNGY06
                                WHERE Y06CODEMP = P_ppcod --AND JNGY42.Y42FECPRO = P_Fecha_finmes_habil
                                            AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                   ) A
               WHERE NVL(Y42DIAATR,0) > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 24 Cliente no debe contar con créditos prorrogados en el último mes (Marca Prórroga). - Cruza PO vs ultimo stock de prorrogas al cierre
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 24;

            BEGIN
              SELECT 24 INTO P_F012FLAG1
              FROM JNGY06
              INNER JOIN XWF700 ON XWfEmpresa  = Y06CODEMP
                                    AND XWfSucursal = Y06SUCCLI
                                    AND XWfModulo   = Y06CODMOD
                                    AND XWfMoneda   = Y06CODMON
                                    AND XWfPapel    = P_WFPAPEL
                                    AND XWfCuenta   = Y06CTACLI
                                    AND XWfOperacion= Y06CODOPE
                                    AND XWfSubope   = Y06SUBOPE
                                    AND XWfTipOpe   = Y06TIPOPE
              INNER JOIN WFATTSVALUES ON WFATTSVALUES.WFInsPrcId = XWF700.XWFPRCINS
                                    AND TRIM(WFATTSVALUES.WFAttSId) = 'PRORROGAS_REALIZADAS'
              WHERE Y06CODEMP = P_ppcod
                    --AND Y06FECPRO = P_Fecha_finmes_habil
                    AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                    AND Y06DIAATR > 30
                    AND TO_NUMBER(WFAttSVal)>0
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 25 Cliente no debe tener en las ultimas 3 cuotas pagadas del cronograma > 8 días de atraso (Marca Utl 3 Cuotas). Buscar las 3 ultimas cuotas pagadas de créditos vigentes o cancelados
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 AND P_Vigente = 1 THEN
            V_REGLA := 25;

            BEGIN
              SELECT 25 INTO P_F012FLAG1
                        FROM (
                                SELECT ROWID_A
                                    , MIN(NroDias) AS NroDiasMax
                                FROM (
                                       SELECT Y06CTACLI AS ROWID_A
                                                ,Y06CODOPE, Y06SUBOPE, Y06TIPOPE
                                              ,(FSD602.Pp1fech - FSD602.Ppfpag) AS NroDias
                                              ,DENSE_RANK() OVER(PARTITION BY Y06CTACLI,Y06CODOPE, Y06SUBOPE, Y06TIPOPE ORDER BY FSD602.PP1NUMP DESC) AS IDOrden
                                       FROM JNGY06
                                       INNER JOIN FSD601 ON FSD601.Pgcod = Y06CODEMP
                                                         AND FSD601.Ppmod = Y06CODMOD
                                                         AND FSD601.Ppsuc = Y06SUCCLI
                                                         AND FSD601.Ppmda = Y06CODMON
                                                         AND FSD601.Pppap = P_WFPAPEL
                                                         AND FSD601.Ppcta = Y06CTACLI
                                                         AND FSD601.Ppoper = Y06CODOPE
                                                         AND FSD601.Ppsbop = Y06SUBOPE
                                                         AND FSD601.Pptope = Y06TIPOPE
                                       INNER JOIN FSD602 ON FSD602.Pgcod = FSD601.Pgcod
                                                         AND FSD602.Ppmod = FSD601.Ppmod
                                                         AND FSD602.Ppsuc = FSD601.Ppsuc
                                                         AND FSD602.Ppmda = FSD601.Ppmda
                                                         AND FSD602.Pppap = FSD601.Pppap
                                                         AND FSD602.Ppcta = FSD601.Ppcta
                                                         AND FSD602.Ppoper = FSD601.Ppoper
                                                         AND FSD602.Ppsbop = FSD601.Ppsbop
                                                         AND FSD602.Pptope = FSD601.Pptope
                                                         AND FSD602.Ppfpag = FSD601.Ppfpag
                                                         AND FSD602.Pptipo = FSD601.Pptipo
                                                         AND FSD602.PP1stat = 'T'
                                            WHERE Y06CODEMP = P_ppcod
                                                    --AND JNGY42.Y42FECPRO = P_Fecha_finmes_habil
                                                    AND Y06TIPDOC = P_PETDOC AND Y06NUMDOC = P_PENDOC
                                    ) B
                                WHERE IDOrden<=3
                                GROUP BY ROWID_A
                            ) A
                        WHERE (CASE WHEN NroDiasMax>=0 THEN 0 ELSE ABS(NroDiasMax) END) > 8;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 26 Cliente no debe tener créditos refinanciados en FC - 24 meses (Marca Refinanciado). Indicador de cartera diga refinaciada
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 26;

            BEGIN
              SELECT 26 INTO P_F012FLAG1
                        FROM (
                               SELECT SUM((CASE WHEN TRIM(Y42INDCAR) = 'REFINANCIADO' THEN 1 ELSE 0 END)) AS NROREFI
                               FROM JNGY42
                               WHERE JNGY42.Y42CODEMP = P_ppcod
                                    AND JNGY42.Y42FECPRO IN (
                                                             SELECT MAX(FFECHA) AS FECHCIERRE
                                                             FROM (
                                                                    SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                    FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                                AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_finmes_habil,-23), 'MM') AND P_Fecha_finmes_habil
                                                                   ) A
                                                             GROUP BY LASTFECHA
                                                            )
                                    AND JNGY42.Y42TIPDOC = P_PETDOC AND JNGY42.Y42NUMDOC = P_PENDOC
                            ) A
                        WHERE NROREFI>0
                    AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 27 Cliente no debe tener máximo día de atraso histórico (12 meses) > 8 días de atraso (Marca Max Dias Atraso)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 27;

            BEGIN
              SELECT 27 INTO P_F012FLAG1
                        FROM (
                               SELECT SUM((CASE WHEN NVL(Y42DIAATR,0) > 8  THEN 1 ELSE 0 END)) AS NROAtra
                               FROM JNGY42
                               WHERE JNGY42.Y42CODEMP = P_ppcod
                                    AND JNGY42.Y42FECPRO IN (
                                                                    SELECT MAX(FFECHA) AS FECHCIERRE
                                                                    FROM (
                                                                            SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                            FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                            AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_finmes_habil,-11), 'MM') AND P_Fecha_finmes_habil
                                                                         ) A
                                                                    GROUP BY LASTFECHA
                                                            )
                                    AND JNGY42.Y42TIPDOC = P_PETDOC AND JNGY42.Y42NUMDOC = P_PENDOC
                            ) A
                        WHERE NROAtra > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 28 Cliente sin crédito de Línea de Gobierno en FC en 24 meses
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 28;

            BEGIN
              SELECT 28 INTO P_F012FLAG1
                        FROM (
                               SELECT SUM((CASE WHEN Y42TIPOPE IN (112,122,123,200,150)  THEN 1 ELSE 0 END)) AS NROCredLG
                               FROM JNGY42
                               WHERE JNGY42.Y42CODEMP = P_ppcod
                                    AND JNGY42.Y42FECPRO IN (
                                                                    SELECT MAX(FFECHA) AS FECHCIERRE
                                                                    FROM (
                                                                            SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                            FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                            AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_finmes_habil,-23), 'MM') AND P_Fecha_finmes_habil
                                                                         ) A
                                                                    GROUP BY LASTFECHA
                                                            )
                                    AND JNGY42.Y42TIPDOC = P_PETDOC AND JNGY42.Y42NUMDOC = P_PENDOC
                            ) A
                        WHERE NROCredLG > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 29 Cliente no debde tener % variación deuda en FC en los últimos 6 meses, últimos 3 meses y 9 meses  mayor 25% -->solo considera el de 6meses (saldo actual/saldo hace 6 meses - 1)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 29;

            BEGIN
              SELECT 29 INTO P_F012FLAG1
                        FROM (
                                SELECT Y42CTACLI
                                        ,(CASE WHEN NVL(SALCAP_MES,0.00) = 0.00 THEN 0.00
                                               WHEN NVL(SALCAP_06,0.00)  = 0.00 AND NVL(SALCAP_MES,0.00) <> 0.00 THEN 100.00
                                               WHEN NVL(SALCAP_06,0.00)  = 0.00 AND NVL(SALCAP_MES,0.00) = 0.00 THEN 0.00
                                               ELSE ((NVL(SALCAP_MES,0.00) / NVL(SALCAP_06,0.00)) - 1) END) AS Var_deuda_FC_6M
                                FROM (
                                           SELECT Y42CTACLI
                                                        , SUM((CASE WHEN Y42FECPRO = P_Fecha_finmes_habil THEN Y42SALCAP ELSE 0.00 END)) AS SALCAP_MES
                                                        , SUM((CASE WHEN Y42FECPRO = P_Fecha_finmes_habil THEN 0.00 ELSE Y42SALCAP END)) AS SALCAP_06
                                           FROM JNGY42
                                           WHERE JNGY42.Y42CODEMP = P_ppcod
                                                AND JNGY42.Y42FECPRO IN (
                                                                                            SELECT FECHCIERRE
                                                                                            FROM (
                                                                                                    SELECT FECHCIERRE,DENSE_RANK() OVER( ORDER BY FECHCIERRE DESC) AS ORDENID
                                                                                                    FROM
                                                                                                    (
                                                                                                        SELECT MAX(FFECHA) AS FECHCIERRE
                                                                                                        FROM (
                                                                                                                SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                                                                FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                                                                AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_finmes_habil,-5), 'MM') AND P_Fecha_finmes_habil
                                                                                                             ) A
                                                                                                        GROUP BY LASTFECHA
                                                                                                    ) B
                                                                                                  ) A
                                                                                             WHERE ORDENID IN(1,6)
                                                                        )
                                                AND JNGY42.Y42TIPDOC = P_PETDOC AND JNGY42.Y42NUMDOC = P_PENDOC
                                            GROUP BY Y42CTACLI
                                    ) C
                             ) B
                        WHERE Var_deuda_FC_6M > 0.25
                              AND ROWNUM = 1;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 30 No se consideran clientes cuyo giro de negocio se encuentren restringidos según normativa (se toma la evaluación mas actual de la PO)
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 30;

            BEGIN
              SELECT 30 INTO P_F012FLAG1
              FROM (
                        SELECT SUM((CASE WHEN SNG028Can1 IN (130,220,132) THEN 1 ELSE 0 END )) AS NroGiro
                        FROM (
                               SELECT MAX(SNG021Eval) AS SNG021Eval
                               FROM SNG021
                               WHERE SNG021.SNG021PDoc = P_Pfpais
                                    AND SNG021.SNG021TDoc = P_PETDOC
                                    AND SNG021.SNG021NDoc = P_PENDOC
                                    AND SNG021.SNG021TMod = 21
                                    AND SNG021.SNG021Eval > 0
                            ) A
                            INNER JOIN SNG028 ON  SNG028.SNG021EVAL = A.SNG021Eval AND SNG028.SNG026COD = 3371
                                                AND SNG028.SNG028LIN <> 999
                    ) A
             WHERE NroGiro > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 31 Cliente no debe tener créditos reprogramados covid en otras entidades en el último RCC disponible
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 31;

            BEGIN
              SELECT 31 INTO P_F012FLAG1
              FROM JNGZ663
              INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR AND JNGZ240.Z240FECREP = P_Fecha_MesAntFin
              WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                    AND TRIM(Z240CODENT) NOT IN ('0','231','00231') AND TRIM(Z240CODPUC) LIKE '81_937%';
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 32 Cliente sin crédito de Línea de Gobierno en otras entidades ultimo RCC
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 32;

            BEGIN
              SELECT 32 INTO P_F012FLAG1
              FROM JNGZ663
              INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR AND JNGZ240.Z240FECREP = P_Fecha_MesAntFin
              WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                    AND TRIM(Z240CODENT) NOT IN ('0','231','00231')
                    AND TRIM(Z240CODPUC) IN
                       (
                         81180102010000, 81181102010000,81193901010000,8119440101000
                        ,81194501000000 ,81180102020000 ,81181102020000 ,81193901020000
                        ,81194401020000 ,81194504000000 ,81180110010000 ,81181110010000
                        ,81193902010000 ,81194403010000 ,81194506000000 ,81180110020000
                        ,81181110020000 ,81193902020000 ,81194403020000 ,81194508000000
                        ,81180111010000 ,81181111010000 ,81193903010000 ,81194404010000
                        ,81180111020000 ,81181111020000 ,81193903020000 ,81194404020000
                        ,81180112010000 ,81181112010000 ,81193904010000 ,81194406010000
                        ,81180112020000 ,81181112020000 ,81193904020000 ,81194406020000
                        ,81180113010000 ,81181113010000 ,81193905010000 ,81194408010000
                        ,81180113020000 ,81181113020000 ,81193905020000 ,81194408020000
                        ,81180502010000 ,81181114010000 ,81193906010000 ,81194409010000
                        ,81180502020000 ,81181114020000 ,81193906020000 ,81194409020000
                        ,81180510010000 ,81181116010000 ,81193907010000 ,81194410020000
                        ,81180510020000 ,81181116020000 ,81193907020000 ,81194411010000
                        ,81180511010000 ,81181117010000 ,81193908010000 ,81194411020000
                        ,81180511020000 ,81181117020000 ,81193908020000 ,81194413010000
                        ,81180512010000 ,81181118010000 ,81193909010000 ,81194413020000
                        ,81180512020000 ,81181118020000 ,81193909020000 ,81194414010000
                        ,81180513010000 ,81194001010000 ,81194414020000 ,81180513020000
                        ,81194001020000 ,81194002010000 ,81194002020000 ,81194003010000
                        ,81194003020000 ,81194004010000 ,81194004020000 ,81194005010000
                        ,81194005020000 ,81194006010000 ,81194006020000 ,81194201010000
                        ,81194201020000 ,81194202010000 ,81194202020000 ,81194203010000
                        ,81194203020000 ,81194204010000 ,81194204020000 ,81194205010000
                        ,81194205020000 ,81194206010000 ,81194206020000 ,81194301010000
                        ,81194301020000 ,81194302010000 ,81194302020000 ,81194303010000
                        ,81194303020000 ,81194304010000 ,81194304020000 ,81194305010000
                        ,81194305020000 ,81194701010000 ,81194701020000 ,81194702010000
                        ,81194702020000 ,81194703010000 ,81194703020000 ,81194704010000
                        ,81194704020000 ,81194705010000 ,81194705020000 ,81194706010000
                        ,81194706020000 ,81194707010000 ,81194707020000 ,81194708010000
                        ,81194708020000 ,81194801010000 ,81194801020000 ,81194802010000
                        ,81194802020000 ,81194803010000 ,81194803020000 ,81194804010000
                        ,81194804020000 ,81194805010000 ,81194805020000 ,81194806010000
                        ,81194806020000 ,81293902010000 ,81293902020000 ,81293903010000
                        ,81293903020000 ,81293905010000 ,81293905020000
                       );
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 33 - A - Solo personas sin cónyuge o que no tienen registrado su conyugue codsbs / Cliente no debe tener mayor a 3 entidades último RCC (titular + cónyuge). (Marca flag_entFAM).
      -----------------------------------------------------------------------
      ------------------------------------------------------------------------
      --Regla 33 - B - Solo personas con conyugue que tienen codsbs / Cliente no debe tener mayor a 3 entidades último RCC (titular + cónyuge). (Marca flag_entFAM).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 33;

            BEGIN
              SELECT 33 INTO P_F012FLAG1
              FROM (
                      SELECT COUNT(1) AS NroEntidades
                      FROM JNGZ663
                      INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR AND JNGZ240.Z240FECREP = P_Fecha_MesAntFin
                      WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                            AND RTRIM(LTRIM(NVL(Z240CODENT,'0'))) NOT IN ('0')
                            AND TRIM(Z240CODPUC) LIKE '14_1%'
                    ) A
             WHERE NroEntidades > 3;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 34 - A - Solo personas titulares registrado tipo documento cony EN EL RCC ACTUAL ( no debe tener calificación diferente a Normal en los últimos 12 meses en el RCC (Marca Cony Clasif).
      -----------------------------------------------------------------------
     ------------------------------------------------------------------------
      --Regla 34 - B - Solo personas cónyuges registrado tipo documento cony EN EL RCC ACTUAL ( no debe tener calificación diferente a Normal en los últimos 12 meses en el RCC (Marca Cony Clasif).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 34;

            BEGIN
              SELECT 34 INTO P_F012FLAG1
              FROM (
                      SELECT COUNT(1) AS NroCalNoNormal
                      FROM JNGZ663
                      INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR
                      WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                            AND JNGZ240.Z240FECREP IN (
                                                                    SELECT LASTFECHA AS FECHCIERRECAL --Fecha cierre calendario para RCC
                                                                    FROM (
                                                                            SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                            FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                            AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_MesAntFin,-11), 'MM') AND P_Fecha_MesAntFin
                                                                         ) A
                                                                    GROUP BY LASTFECHA
                                                      )
                            -- AND TRIM(NVL(Z240CODENT,'')) NOT IN ('0','') GENERA ERROR DESCONOCIDO
                            AND NVL(TRIM(Z240CODENT), '-') NOT IN ('0', ' ', '-')
                            AND TRIM(Z240CALEMP) <> '0'
                    ) A
             WHERE NroCalNoNormal > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 35 - A - Solo personas titulares registrado tipo documento cony EN EL RCC ACTUAL - CALIF_36M_DDP / Cliente no debe tener calificación deficiente, dudoso o pérdida últimos 36 meses (Marca Calif36M).
      -----------------------------------------------------------------------
    ------------------------------------------------------------------------
      --Regla 35 - B - Solo personas cónyuges registrado tipo documento cony EN EL RCC ACTUAL castigos / Cliente no debe tener calificación deficiente, dudoso o pérdida últimos 36 meses (Marca Calif36M).
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 35;

            BEGIN
              SELECT 35 INTO P_F012FLAG1
              FROM (
                      SELECT COUNT(1) AS NroCalNoNormal --deficiente, dudoso o pérdida
                      FROM JNGZ663
                      INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR
                      WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                            AND JNGZ240.Z240FECREP IN (
                                                                    SELECT LASTFECHA AS FECHCIERRECAL --Fecha cierre calendario para RCC
                                                                    FROM (
                                                                            SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                            FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                            AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_MesAntFin,-35), 'MM') AND P_Fecha_MesAntFin
                                                                         ) A
                                                                    GROUP BY LASTFECHA
                                                      )
                            -- AND TRIM(NVL(Z240CODENT,'')) NOT IN ('0','')     GENERA ERROR DESCONOCIDO
                            AND NVL(TRIM(Z240CODENT), '-') NOT IN ('0', ' ', '-')
                            AND TRIM(Z240CALEMP) NOT IN ('0','1')
                    ) A
             WHERE NroCalNoNormal > 0;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;

      ------------------------------------------------------------------------
      --Regla 36 - A - Solo personas titulares registrado tipo documento cony EN EL RCC ACTUAL - castigos Cliente/ Cónyuge (si estuviese) no debe haber tenido ningún crédito castigado en el RCC (Marca Castigo RCC). Durante los ultimos 36 meses, desde RCC disponible
      -----------------------------------------------------------------------
    ------------------------------------------------------------------------
      --Regla 36 - B - Solo personas cónyuges registrado tipo documento cony EN EL RCC ACTUAL castigos / Cliente/ Cónyuge (si estuviese) no debe haber tenido ningún crédito castigado en el RCC (Marca Castigo RCC). Durante los ultimos 36 meses, desde RCC disponible
      -----------------------------------------------------------------------
        IF P_F012FLAG1 = 0 THEN
            V_REGLA := 36;

            BEGIN
              SELECT 36 INTO P_F012FLAG1
              FROM (
                      SELECT SUM((CASE WHEN substr(trim(Z240CODPUC),4,3) IN ('302','925') THEN 1 ELSE 0 END)) AS NroCredCan
                      FROM JNGZ663
                      INNER JOIN JNGZ240 ON JNGZ240.Z240CORR = Z663CORR
                      WHERE Z663CORR = P_Z663CORR  AND Z663PAIS = P_PEPAIS AND Z663TDOC = P_PETDOC AND Z663NDOC = P_PENDOC
                            AND JNGZ240.Z240FECREP IN (
                                                                    SELECT LASTFECHA AS FECHCIERRECAL --Fecha cierre calendario para RCC
                                                                    FROM (
                                                                            SELECT FFECHA,LAST_DAY(FFECHA) AS LASTFECHA
                                                                            FROM FST028 WHERE FHABIL = 'S' AND CALCOD = ( SELECT CalCod FROM FST001 WHERE PGCOD = P_ppcod AND SUCURS = P_Sucurs)
                                                                            AND FFECHA BETWEEN TRUNC(ADD_MONTHS(P_Fecha_MesAntFin,-35), 'MM') AND P_Fecha_MesAntFin
                                                                         ) A
                                                                    GROUP BY LASTFECHA
                                                      )
                            -- AND TRIM(NVL(Z240CODENT,'')) NOT IN ('0','')     GENERA ERROR DESCONOCIDO
                            AND NVL(TRIM(Z240CODENT), '-') NOT IN ('0', ' ', '-')
                            AND TRIM(Z240CODPUC) LIKE '81%'
                    ) A
             WHERE NroCredCan > 0;

            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     P_F012FLAG1 := 0;
            END;
        END IF;
  END IF;
    P_F012FLAG_VAL := P_F012FLAG1;

    P_INDOPE :='0';
    P_SQLERRM := P_SQLERRM || 'OK|';

    -- Se obtiene la hora fin del proceso
    SELECT TO_CHAR(SYSDATE,'HH24:MI:SS') INTO P_JCOL115HFIN  FROM DUAL;

    If V_GENERALOG = 1 THEN
        SP_JCOL116LOG(
              P_JCOL115USER => ' '
              ,P_JCOL115PRGM => 'SP_REGSEL'
              ,P_JCOL115SRV  => 'Valida Reglas de Ofertas Online'
              ,P_JCOL115SRVD => 'P01:P_PEPAIS | P02:P_PETDOC | P03:P_NRODOC | P04:P_CTNRO | P05:P_Z663CORR | P06: | P07:P_CodOferta | P08:P_PlzOfFin  | P09:P_CuotaOfFin | P10:P_MontOfFin'
              ,P_JCOL115P01  => TO_CHAR(P_PEPAIS)
              ,P_JCOL115P02  => TO_CHAR(P_PETDOC)
              ,P_JCOL115P03  => P_NRODOC
              ,P_JCOL115P04  => TO_CHAR(P_CTNRO)
              ,P_JCOL115P05  => TO_CHAR(P_Z663CORR)
              ,P_JCOL115P06  => ' '
              ,P_JCOL115P07  => ' '
              ,P_JCOL115P08  => ' '
              ,P_JCOL115P09  => ' '
              ,P_JCOL115P10  => ' '
              ,P_JCOL115XMLI => ' '
              ,P_JCOL115XMLO => ' '
              ,P_JCOL115ERID => TO_NUMBER(P_F012FLAG_VAL)
              ,P_JCOL115ERDE => P_SQLERRM
              ,P_JCOL115TXT1 => ' '
              ,P_JCOL115TXT2 => ' '
              ,P_JCOL115TXT3 => ' '
              ,P_JCOL115NUM1 => P_Vigente
              ,P_JCOL115NUM2 => 0
              ,P_JCOL115NUM3 => 0
              ,P_JCOL115FEC1 => P_Fecha_MesAntIni
              ,P_JCOL115FEC2 => P_Fecha_finmes_habil
              ,P_JCOL115FEC3 => P_Fecha_MesAntFin
              ,P_JCOL115HINI => P_JCOL115HINI
              ,P_JCOL115HFIN => P_JCOL115HFIN
        );

        COMMIT;
    END IF;

    FCINSTROUT();
EXCEPTION
    WHEN OTHERS THEN
        P_F012FLAG_VAL:=99;
        P_INDOPE := TO_CHAR(SQLCODE);
        P_SQLERRM := P_SQLERRM || SQLERRM;

    -- Se obtiene la hora fin del proceso
    SELECT TO_CHAR(SYSDATE,'HH24:MI:SS') INTO P_JCOL115HFIN  FROM DUAL;

    SP_JCOL116LOG(
          P_JCOL115USER => ' '
          ,P_JCOL115PRGM => 'SP_REGSEL'
          ,P_JCOL115SRV  => 'Valida Reglas de Ofertas Online Exception'
          ,P_JCOL115SRVD => 'P01:P_PEPAIS | P02:P_PETDOC | P03:P_NRODOC | P04:P_CTNRO | P05:P_Z663CORR | P06: | P07:P_CodOferta | P08:P_PlzOfFin  | P09:P_CuotaOfFin | P10:P_MontOfFin'
          ,P_JCOL115P01  => TO_CHAR(P_PEPAIS)
          ,P_JCOL115P02  => TO_CHAR(P_PETDOC)
          ,P_JCOL115P03  => P_NRODOC
          ,P_JCOL115P04  => TO_CHAR(P_CTNRO)
          ,P_JCOL115P05  => TO_CHAR(P_Z663CORR)
          ,P_JCOL115P06  => ' '
          ,P_JCOL115P07  => ' '
          ,P_JCOL115P08  => ' '
          ,P_JCOL115P09  => ' '
          ,P_JCOL115P10  => ' '
          ,P_JCOL115XMLI => ' '
          ,P_JCOL115XMLO => ' '
          ,P_JCOL115ERID => TO_NUMBER(V_REGLA)
          ,P_JCOL115ERDE => P_SQLERRM
          ,P_JCOL115TXT1 => ' '
          ,P_JCOL115TXT2 => ' '
          ,P_JCOL115TXT3 => ' '
          ,P_JCOL115NUM1 => P_Vigente
          ,P_JCOL115NUM2 => 0
          ,P_JCOL115NUM3 => 0
          ,P_JCOL115FEC1 => P_Fecha_MesAntIni
          ,P_JCOL115FEC2 => P_Fecha_finmes_habil
          ,P_JCOL115FEC3 => P_Fecha_MesAntFin
          ,P_JCOL115HINI => P_JCOL115HINI
          ,P_JCOL115HFIN => P_JCOL115HFIN
    );

    COMMIT;

    FCINSTROUT();
END SP_REGSEL;