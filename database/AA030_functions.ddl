-- Use this script to add your database functions.

SET search_path TO :"nspace", :"apinspace", public;

-- simple random function (not crypto secure)
CREATE OR REPLACE FUNCTION random_between(low INT ,high INT)
    RETURNS INT AS
$$
BEGIN
    RETURN floor(random()* (high-low + 1) + low);
END;
$$ language 'plpgsql' STRICT;


CREATE OR REPLACE FUNCTION luhn_verify(int8) RETURNS boolean AS $body$
-- Take the sum of the
-- doubled digits and the even-numbered undoubled digits, and see if
-- the sum is evenly divisible by zero.
SELECT
    -- Doubled digits might in turn be two digits. In that case,
    -- we must add each digit individually rather than adding the
    -- doubled digit value to the sum. Ie if the original digit was
    -- `6' the doubled result was `12' and we must add `1+2' to the
    -- sum rather than `12'.
    MOD(SUM(doubled_digit / INT8 '10' + doubled_digit % INT8 '10'), 10) = 0
FROM
-- Double odd-numbered digits (counting left with
-- least significant as zero). If the doubled digits end up
-- having values
-- > 10 (ie they're two digits), add their digits together.
(SELECT
     -- Extract digit `n' counting left from least significant
     -- as zero
     MOD( ( $1::int8 / (10^n)::int8 ), 10::int8)
         -- Double odd-numbered digits
         * (MOD(n,2) + 1)
         AS doubled_digit
 FROM generate_series(0, floor(log( $1 ))::integer) AS n
) AS doubled_digits;

$body$ LANGUAGE SQL
    IMMUTABLE
    STRICT;

COMMENT ON FUNCTION luhn_verify(int8) IS 'Return true iff the last digit of the
input is a correct check digit for the rest of the input according to Luhn''s
algorithm.';

CREATE OR REPLACE FUNCTION luhn_generate_checkdigit(int8) RETURNS int8 AS $body$
SELECT
    -- Add the digits, doubling even-numbered digits (counting left
    -- with least-significant as zero). Subtract the remainder of
    -- dividing the sum by 10 from 10, and take the remainder
    -- of dividing that by 10 in turn.
    ((INT8 '10' - SUM(doubled_digit / INT8 '10' + doubled_digit % INT8 '10') %
                  INT8 '10') % INT8 '10')::INT8
FROM (SELECT
          -- Extract digit `n' counting left from least significant\
          -- as zero
          MOD( ($1::int8 / (10^n)::int8), 10::int8 )
              -- double even-numbered digits
              * (2 - MOD(n,2))
              AS doubled_digit
      FROM generate_series(0, floor(log( $1 ))::integer) AS n
     ) AS doubled_digits;

$body$ LANGUAGE SQL
    IMMUTABLE
    STRICT;

COMMENT ON FUNCTION luhn_generate_checkdigit(int8) IS 'For the input
value, generate a check digit according to Luhn''s algorithm';

CREATE OR REPLACE FUNCTION luhn_generate(int8) RETURNS int8 AS $body$
SELECT 10 * $1 + luhn_generate_checkdigit($1);
$body$ LANGUAGE SQL
    IMMUTABLE
    STRICT;

COMMENT ON FUNCTION luhn_generate(int8) IS 'Append a check digit generated
according to Luhn''s algorithm to the input value. The input value must be no
greater than (maxbigint/10).';

CREATE OR REPLACE FUNCTION luhn_strip(int8) RETURNS int8 AS $body$
SELECT $1 / 10;
$body$ LANGUAGE SQL
    IMMUTABLE
    STRICT;

COMMENT ON FUNCTION luhn_strip(int8) IS 'Strip the least significant digit from
the input value. Intended for use when stripping the check digit from a number
including a Luhn''s algorithm check digit.';



CREATE OR REPLACE FUNCTION prng(x bigint) RETURNS bigint AS $body$
DECLARE
    prime constant bigint := 4294967291;
    res numeric;
    retval bigint;
BEGIN
    --RAISE DEBUG 'Entering prng with:%', x;
    -- the 5 integers out of range are mapped to themselves.
    IF x > prime THEN
        SELECT x INTO retval;
        return retval;
    ELSE
        SELECT MOD( (x::numeric * x::numeric), prime) INTO res;
    END IF;
    IF x <= (prime/2) THEN
        SELECT res INTO retval;
    ELSE
        SELECT (prime-res) INTO retval;
    END IF;
    return retval;
END;
$body$
    LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION account_number(x bigint) RETURNS bigint AS $body$
DECLARE
    intermediatOffset constant bigint := 4294967291;
    retval bigint;
BEGIN
    --
    SELECT luhn_generate(prng(prng(x)+1000000000) # (('x' || '5bf03635')::bit(32)::bigint)) INTO retval;  --# 0x5bf03635
    return retval;
END;
$body$
    LANGUAGE 'plpgsql';