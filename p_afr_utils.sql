create or replace PACKAGE BODY                 p_afr_utils IS

PROCEDURE abo_insert_contact
 (p_numabo           IN abo_abonn.numabo%TYPE
 ,p_numabont         IN abo_abont.numabont%TYPE
 ,p_ccommunic        IN cod_communication.ccommunic%TYPE
 ,p_cpositionnement  IN cod_positionnement.cpositionnement%TYPE
 ,p_grpctccateg      IN cod_grpctccateg.cgrpctccateg %TYPE
 ,p_ctccateg         IN cod_grpctccategdet.ctccateg%TYPE
 ,p_cclimat          IN cod_climat.cclimat%TYPE
 ,p_cctcstatus       IN cod_ctcstatus.cctcstatus%TYPE
 ,p_cctcresult       IN cod_ctcresult.cctcresult%TYPE
 ,p_position         IN abo_contactdet.position%TYPE := '1'
 ,p_freetextarea     IN abo_contact.freetextarea%TYPE
 ,p_usercre          IN mnu_user.cuser%TYPE
 ,p_datcre           IN DATE DEFAULT SYSDATE
 ,p_datclose         IN DATE DEFAULT SYSDATE)
IS
/**********************************************************************************************/
/* creation du contact et du detail du contact pour un seul theme                             */
/*                                                                                            */
/*  p_numabo : numero abonne                                                                  */
/*  p_numabont : numero d'abonnement                                                          */
/*  p_ccommunic : code communication                                                          */
/*  p_cpositionnement : code positionnement                                                   */
/*  p_grpctccateg : code de groupe de categorie                                               */
/*  p_ctccateg : code categorie                                                               */
/*  p_cclimat : code climat                                                                   */
/*  p_cctcstatus : code statut                                                                */
/*  p_cctcresult :  code resultat                                                             */
/*  p_position : position de l'adresse (1 ou 2)                                               */
/*  p_freetextarea : commentaire                                                              */
/*  p_usercre : cuser de la personne ayant fait le contact                                    */
/*  p_datcre : date de creation du contact                                                    */
/*  p_datclose : date de cloture                                                              */
/*                                                                                            */
/* Karlo Godicelj  06/08/2014   creation                                                      */
/**********************************************************************************************/
  wnumcontact abo_contact.numcontact%TYPE;

BEGIN
  SELECT numcontact_seq.NEXTVAL
  INTO wnumcontact
  FROM dual;

  INSERT INTO abo_contact (numcontact, numabo, numabont, cpositionnement, ccommunic, dateclose,
                           datcre, usercre, freetextarea, cclimat, cctcstatus, cctcresult, datmod, usermod)
  VALUES (wnumcontact, p_numabo, p_numabont, p_cpositionnement, p_ccommunic, p_datclose,
          p_datcre, p_usercre, p_freetextarea, p_cclimat, p_cctcstatus, p_cctcresult, SYSDATE, p_usercre);

  IF p_grpctccateg IS NOT NULL AND p_ctccateg IS NOT NULL THEN
    INSERT INTO abo_contactdet (numcontact, cgrpctccateg, ctccateg, position)
    VALUES (wnumcontact, p_grpctccateg, p_ctccateg, p_position);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
    DBMS_OUTPUT.put_line(SQLERRM);
END ABO_INSERT_CONTACT;

PROCEDURE abo_insert_phone (p_phonenumber IN abo_phones.numphone%TYPE,
                            p_numabo      IN abo_abonn.numabo%TYPE,
                            p_usercre     IN mnu_user.cuser%TYPE,
                            p_cphonetype  IN abo_phones.cphonetype%TYPE,
                            p_datcre      IN DATE DEFAULT SYSDATE)
IS
/**********************************************************************************************/
/* Cette procedure de mise a jour des numeros de telephone des abonnes                        */
/*                                                                                            */
/*  p_phonenumber : numero de telephone                                                       */
/*  p_numabo : numero d'abonne                                                                */
/*  p_usercre : user ayant saisie le contact                                                  */
/*  p_cphonetype : type de telephone (MOBILE1, MOBILE2, WORK1, WORK2, HOME1, HOME2)           */
/*  p_datcre : date du contact                                                                */
/*                                                                                            */
/* Karlo Godicelj  06/08/2014   creation                                                      */
/**********************************************************************************************/

  wnewphone   NUMBER:=0;

BEGIN
  --parametre non null
  IF p_phonenumber IS NOT NULL AND p_numabo IS NOT NULL AND p_usercre IS NOT NULL AND p_cphonetype IS NOT NULL AND p_datcre IS NOT NULL THEN
    --ajout des abonnement qui n'ont pas de numero de telephone enregistre
    INSERT INTO abo_phones (numphone, numabo, numabont, phonenumber, cphonetype, debval, usercre, datcre)
    SELECT newnumphone_seq.nextval, t.numabo, t.numabont, p_phonenumber, p_cphonetype, p_datcre, p_usercre, p_datcre
    FROM abo_abont t
    WHERE NOT EXISTS (SELECT 1
                      FROM abo_phones p
                      WHERE p.numabo = t.numabo
                      AND p.numabont = t.numabont)
    AND t.numabo = p_numabo;

    --l'abonne a deja un numero de telephone enregistre
    -- et si celui-ci change, on historise le numero actuel
    INSERT INTO abo_phones_jour (numphonejour, numphone, phonenumber, cphonetype, debval, finval, usermod, datmod, ind3g, ind3gplus)
    SELECT newnumphonejour_seq.nextval, numphone, phonenumber, cphonetype, debval, finval, usermod, datmod, ind3g, ind3gplus
    FROM (SELECT DISTINCT p.numphone, p.phonenumber, p.cphonetype, p.debval, p.finval, p.usermod, p.datmod, p.ind3g, p.ind3gplus
          FROM abo_phones p
          WHERE p.numabo = p_numabo
          AND p.cphonetype = p_cphonetype
          AND p.phonenumber != p_phonenumber);

    --maj de l'ancien numero de telephone par le nouveau si il sont different
    UPDATE abo_phones p
    SET p.phonenumber = p_phonenumber, p.usermod = p_usercre, p.datmod = p_datcre
    WHERE p.numabo = p_numabo
    AND p.cphonetype = p_cphonetype
    AND p.phonenumber != p_phonenumber;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END abo_insert_phone;


function get_last_xday
(
  i_jour in varchar2
 ,i_date in date default sysdate
) return date
  /******************************************************************************
     NOM:    get_last_xday
     ROLE: Retourne la date du dernier lundi/mardi/.../samedi/dimanche
           du mois dont la date est passée en paramètre.
     DEPENDANCES : aucune
     RETOUR : une date
     REVISIONS:
     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0        17/09/2015  V. BRU           Création


  ******************************************************************************/
as
  e_param_error exception;
  l_jour number := null;
  l_date date := null;


begin

  -- contrôle des paramètres d'entrée
  if i_jour is null then
    raise e_param_error;
  end if;

  if i_date is null then
    l_date := sysdate;
  else
    l_date := i_date;
  end if;

  -- transco du numéro de jour dans la semaine du paramètre d'appel
  case
    when lower(i_jour) = 'lundi'    or i_jour = '1' then l_jour := 1;
    when lower(i_jour) = 'mardi'    or i_jour = '2' then l_jour := 2;
    when lower(i_jour) = 'mercredi' or i_jour = '3' then l_jour := 3;
    when lower(i_jour) = 'jeudi'    or i_jour = '4' then l_jour := 4;
    when lower(i_jour) = 'vendredi' or i_jour = '5' then l_jour := 5;
    when lower(i_jour) = 'samedi'   or i_jour = '6' then l_jour := 6;
    when lower(i_jour) = 'dimanche' or i_jour = '7' then l_jour := 7;
    else raise e_param_error;
  end case;

  -- on boucle à partir du dernier jour du mois pour voir s'il s'agit du
  -- jour de la semaine recherché. Tant que "non" => on retourne un jour en arrière
  -- On va jusqu'à 7 car il y a 7 jours / semaine... :)
  for i in 0..7 loop
    if to_number(to_char(last_day(l_date)-i,'d'))  = l_jour then
      return last_day(l_date) - i;
    end if;
  end loop;

exception
  when e_param_error then
    raise;
  when others then
    raise;
end get_last_xday;



  -- ----------------------------------------------------------------
  -- nom    : calcul_intervalle_temps
  -- rôle   : renvoie l'intervalle de temps entre deux dates, formaté
  -- dépendances : aucune
  -- entrée : 2 dates
  -- sortie : 1 varchar2 au format - "xx j yy h zz min ss sec" -
  --
  -- Version *    Date    * Auteur         *    Description
  -- -------      ----      ------              -----------
  --   1.0   * 06/10/2015 * V. BRU         *    Création
  --
  --
  --
  -- ----------------------------------------------------------------
  function calcul_intervalle_temps (i_debut date, i_fin date)
  return varchar2
  is
      l_delta     number;
      l_reste     number;
      l_jours     number;
      l_heures    number;
      l_minutes   number;
      l_secondes  number;
  
    begin
  
        -- conbtrôle des params d'appel
        if (i_debut is null or i_fin is null)
        then
            return null;
        end if;
  
        l_delta := (i_fin - i_debut) * 86400;
  
        -- jours
        l_jours := floor(l_delta / 86400);
        l_reste := l_delta - (86400 * l_jours);
  
        -- heures
        l_heures := floor(l_reste / 3600);
        l_reste := l_reste - (3600 * l_heures);
  
        -- minutes
        l_minutes := floor(l_reste / 60);
        l_reste := l_reste - (60 * l_minutes);
  
        -- secondes
        l_secondes := round(l_reste);
  
      return
             to_char(l_jours)||'j'
      ||' '||to_char(l_heures)||' h'
      ||' '||to_char(l_minutes)||' min'
      ||' '||to_char(l_secondes)||' sec'
      ;
  
    exception
      when others then
        raise;
    end calcul_intervalle_temps;



  -- ----------------------------------------------------------------
  -- nom    : get_exchange_rate
  -- rôle   : renvoie le taux de change entre deux devises en tenant
  --          compte du "déversement inverse" multiplié par la somme à 
  --          converit. C'est à dire que si le taux de conversion est < 0 
  --          alors on divise le montant par l'inverse du taux de change 
  --          => Même résultat mais meilleure précision dans le cas où
  --          SAP n'utilse pas toutes les décimales.
  --
  -- dépendances : table "cod_exchangerate
  -- entrée : i_montant      => montant à convertir (NUMBER NOT NULL)
  --          i_devisefrom   => devise de départ (VARCHAR2 NOT NULL)
  --          i_deviseto     => devise d'arrivée (VARCHAR2 NOT NULL)
  --          i_dateexchange => date de conversion (DATE NOT NULL)
  -- sortie : La somme convertie dans la nouvelle monnaie (NUMBER)
  --
  -- Version *    Date    * Auteur         *    Description
  -- -------      ----      ------              -----------
  --   1.0   * 07/10/2015 * V. BRU         *    Création
  --
  --
  --
  -- ----------------------------------------------------------------
  function get_exchange_rate ( i_montant    number
                              ,i_devisefrom varchar2
                              ,i_deviseto   varchar2
                              ,i_dateexchange date
                             ) return number
  is
    r_out number := null;
    e_param_error exception;
  begin

    -- contrôle des params d'appel
    if   i_montant is null
      or i_devisefrom is null
      or i_deviseto is null
      or i_dateexchange is null then
      raise e_param_error;
    end if;

    -- test trivial
    if i_devisefrom = i_deviseto then
      return i_montant;
    end if;

    --
    select decode(sign(rate-1)
                 ,-1
                 ,i_montant/power(rate,-1)
                 ,i_montant*rate)
    into r_out
    from webuser.cod_exchangerate
    where
        cdevisefrom = i_devisefrom
    and cdeviseto   = i_deviseto
    and i_dateexchange between debval and finval
    ;

    return r_out;

  exception
    when e_param_error then
      dbms_output.put_line('input paramaters cannot be empty !'
                         ||cr||'i_devisefrom => "' || i_devisefrom ||'"'
                         ||cr||'i_deviseto   => "' || i_deviseto   ||'"'
                         ||cr||'i_dateexchange => "' || i_dateexchange ||'"'
                         );
      raise;
    when no_data_found then
      dbms_output.put_line('unknown exchange rate'
                         ||cr||'from => "' || i_devisefrom   ||'"'
                         ||cr||'to   => "' || i_deviseto     ||'"'
                         ||cr||'as of "'   || i_dateexchange ||'"'
                         );
      raise;
    when others then
      raise;
  end get_exchange_rate;


   -- ----------------------------------------------------------------
  -- nom    : is_recouvrement_intervalles
  -- rôle   : renvoie "1" si les deux intervalles temporels ont une
  --          intersection, renvoie "0" sinon.
  --
  -- dépendances : aucune
  -- entrée : i_deb1 => date de début intervalle 1 (DATE NOT NULL)
  --          i_fin1 => date de fin intervalle 1   (DATE NOT NULL)
  --          i_deb2 => date de début intervalle 2 (DATE NOT NULL)
  --          i_fin2 => date de fin intervalle 2   (DATE NOT NULL)
  --
  -- sortie : 0 => pas de recouvrement
  --          1 => il existe un recouvrement
  --
  -- Version *    Date    * Auteur         *    Description
  -- -------      ----      ------              -----------
  --   1.0   * 07/10/2015 * V. BRU         *    Création
  --
  --
  --
  -- ----------------------------------------------------------------
  function is_recouvrement_intervalles ( i_deb1 date
                                        ,i_fin1 date
                                        ,i_deb2 date
                                        ,i_fin2 date
                                       ) return number
  is
    e_param_error exception;
  begin

    -- paramètres d'appel non vides ?
    if   i_deb1 is null
      or i_fin1 is null
      or i_deb2 is null
      or i_fin2 is null then
      raise e_param_error;
    end if;

    -- fin postérieure à début ?
    if i_fin1 < i_deb1 or i_fin2 < i_deb2 then
      raise e_param_error;
    end if;

    -- test du recouvrement...
    if   i_fin1 between i_deb2 and i_fin2
      or i_fin2 between i_deb1 and i_fin1 then
      return 1;
    else
      return 0;
    end if;

  exception
    when e_param_error then
      dbms_output.put_line('input paramaters error'
                         ||cr||'i_deb1 => "' || i_deb1 ||'"'
                         ||cr||'i_fin1 => "' || i_fin1 ||'"'
                         ||cr||'i_deb2 => "' || i_deb2 ||'"'
                         ||cr||'i_fin2 => "' || i_fin2 ||'"'
                         );
      raise;
    when others then
      raise;
  end is_recouvrement_intervalles;

END p_afr_utils;