CREATE OR REPLACE FUNCTION age_group(process_start_date TIMESTAMP WITHOUT TIME ZONE,
                                     birthdate          TIMESTAMP WITHOUT TIME ZONE)
  RETURNS CHARACTER VARYING
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXTRACT(YEAR FROM (age(process_start_date, birthdate))) BETWEEN 0 AND 4
  THEN RETURN '0-5';
  ELSEIF EXTRACT(YEAR FROM (age(process_start_date, birthdate))) BETWEEN 5 AND 14
    THEN RETURN '5-15';
  ELSEIF (EXTRACT(YEAR FROM (age(process_start_date, birthdate))) BETWEEN 15 AND 44)
    THEN RETURN '15-45';
  ELSEIF EXTRACT(YEAR FROM (age(process_start_date, birthdate))) >= 45
    THEN RETURN '45+';
ELSE RETURN NULL;
END IF;

END;
$$;