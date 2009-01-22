module Database.HDBC.SqlValue
    (
    SqlType(..), nToSql, iToSql,
    SqlValue(..)
    )

where
import Data.Dynamic
import qualified Data.ByteString as B
import Data.Char(ord,toUpper)
import Data.Word
import Data.Int
import qualified System.Time as ST
import Data.Time
import Data.Time.Clock
import Data.Time.Clock.POSIX
import System.Locale
import Data.Ratio

{- | Conversions to and from 'SqlValue's and standard Haskell types.

Conversions are powerful; for instance, you can call 'fromSql' on a SqlInt32
and get a String or a Double out of it.  This class attempts to Do
The Right Thing whenever possible, and will raise an error when asked to
do something incorrect.  In particular, when converting to any type
except a Maybe, 'SqlNull' as the input will cause an error to be raised.

Here are some notes about conversion:

 * Fractions of a second are not preserved on time values

See also 'nToSql', 'iToSql'.
-}

class (Show a) => SqlType a where
    toSql :: a -> SqlValue
    fromSql :: SqlValue -> a

{- | Converts any Integral type to a 'SqlValue' by using toInteger. -}
nToSql :: Integral a => a -> SqlValue
nToSql n = SqlInteger (toInteger n)

{- | Convenience function for using numeric literals in your program. -}
iToSql :: Int -> SqlValue
iToSql = toSql

{- | The main type for expressing Haskell values to SQL databases.

This type is used to marshall Haskell data to and from database APIs.
HDBC driver interfaces will do their best to use the most accurate and
efficient way to send a particular value to the database server.

Values read back from the server are put in the most appropriate 'SqlValue'
type.  'fromSql' can then be used to convert them into whatever type
is needed locally in Haskell.

Most people will use 'toSql' and 'fromSql' instead of manipulating
'SqlValue's directly.

HDBC database backends are expected to marshal date and time data back and
forth using the appropriate representation for the underlying database engine.
Databases such as PostgreSQL with builtin date and time types should see automatic
conversion between these Haskell types to database types.  Other databases will be
presented with an integer or a string.  Care should be taken to use the same type on
the Haskell side as you use on the database side.  For instance, if your database
type lacks timezone information, you ought not to use ZonedTime, but
instead LocalTime or UTCTime.  Database type systems are not always as rich
as Haskell.  For instance, for data stored in a TIMESTAMP
WITHOUT TIME ZONE column, HDBC may not be able to tell if it is intended
as UTCTime or LocalTime data, and will happily convert it to both, 
upon your request.  It is
your responsibility to ensure that you treat timezone issues with due care.

This behavior also exists for other types.  For instance, many databases do not
have a Rational type, so they will just use the show function and
store a Rational as a string.

The conversion between Haskell types and database types is complex,
and generic code in HDBC or its backends cannot possibly accomodate
every possible situation.  In some cases, you may be best served by converting your
Haskell type to a String, and passing that to the database.

Two SqlValues are considered to be equal if one of these hold.  The
first comparison that can be made is controlling; if none of these
comparisons can be made, then they are not equal:
 * Both are NULL
 * Both represent the same type and the encapsulated values are considered equal
   by applying (==) to them
 * The values of each, when converted to a string, are equal.

Note that a 'NominalDiffTime' or 'POSIXTime' is converted to 'SqlDiffTime' by
'toSQL'.  HDBC cannot differentiate between 'NominalDiffTime' and 'POSIXTime'
since they are the same underlying type.  You must construct 'SqlPOSIXTime'
manually, or use 'SqlUTCTime'.

'SqlEpochTime' and 'SqlTimeDiff' are no longer created automatically by any
'toSql' or 'fromSql' functions.  They may still be manually constructed, but are
expected to be removed in a future version.  Although these two constructures will
be removed, support for marshalling to and from the old System.Time data will be
maintained as long as System.Time is, simply using the newer data types for conversion.

Default string representations are given as comments below where such are non-obvious.
These are used for 'fromSql' when a 'String' is desired.  They are also defaults for
representing data to SQL backends, though individual backends may override them
when a different format is demanded by the underlying database.  Date and time formats
use ISO8601 date format, with HH:MM:SS added for time, and -HHMM added for timezone
offsets.
-}
data SqlValue = SqlString String 
              | SqlByteString B.ByteString
              | SqlWord32 Word32
              | SqlWord64 Word64
              | SqlInt32 Int32
              | SqlInt64 Int64
              | SqlInteger Integer
              | SqlChar Char
              | SqlBool Bool
              | SqlDouble Double
              | SqlRational Rational
              | SqlLocalDate Day            -- ^ Local YYYY-MM-DD (no timezone)
              | SqlLocalTimeOfDay TimeOfDay -- ^ Local HH:MM:SS (no timezone)
              | SqlLocalTime LocalTime      -- ^ Local YYYY-MM-DD HH:MM:SS (no timezone)
              | SqlZonedTime ZonedTime      -- ^ Local YYYY-MM-DD HH:MM:SS -HHMM.  Considered equal if both convert to the same UTC time.
              | SqlUTCTime UTCTime          -- ^ UTC YYYY-MM-DD HH:MM:SS
              | SqlDiffTime NominalDiffTime -- ^ Calendar diff between seconds.  Rendered as Integer when converted to String, but greater precision may be preserved for other types or to underlying database.
              | SqlPOSIXTime POSIXTime      -- ^ Time as seconds since 1/1/1970 UTC.  Integer rendering as for 'SqlDiffTime'.
              | SqlEpochTime Integer      -- ^ DEPRECATED Representation of ClockTime or CalendarTime.  Use SqlPOSIXTime instead.
              | SqlTimeDiff Integer -- ^ DEPRECATED Representation of TimeDiff.  Use SqlDiffTime instead.
              | SqlNull         -- ^ NULL in SQL or Nothing in Haskell
     deriving (Show)

instance Eq SqlValue where
    SqlString a == SqlString b = a == b
    SqlByteString a == SqlByteString b = a == b
    SqlWord32 a == SqlWord32 b = a == b
    SqlWord64 a == SqlWord64 b = a == b
    SqlInt32 a == SqlInt32 b = a == b
    SqlInt64 a == SqlInt64 b = a == b
    SqlInteger a == SqlInteger b = a == b
    SqlChar a == SqlChar b = a == b
    SqlBool a == SqlBool b = a == b
    SqlDouble a == SqlDouble b = a == b
    SqlRational a == SqlRational b = a == b
    SqlLocalTimeOfDay a == SqlLocalTimeOfDay b = a == b
    SqlLocalTime a == SqlLocalTime b = a == b
    SqlLocalDate a == SqlLocalDate b = a == b
    SqlZonedTime a == SqlZonedTime b = zonedTimeToUTC a == zonedTimeToUTC b
    SqlUTCTime a == SqlUTCTime b = a == b
    SqlPOSIXTime a == SqlPOSIXTime b = a == b
    SqlDiffTime a == SqlDiffTime b = a == b
    SqlEpochTime a == SqlEpochTime b = a == b
    SqlTimeDiff a == SqlTimeDiff b = a == b
    SqlNull == SqlNull = True
    SqlNull == _ = False
    _ == SqlNull = False
    a == b = ((fromSql a)::String) == ((fromSql b)::String)

instance SqlType String where
    toSql = SqlString
    fromSql (SqlString x) = x
    fromSql (SqlByteString x) = byteString2String x
    fromSql (SqlInt32 x) = show x
    fromSql (SqlInt64 x) = show x
    fromSql (SqlWord32 x) = show x
    fromSql (SqlWord64 x) = show x
    fromSql (SqlInteger x) = show x
    fromSql (SqlChar x) = [x]
    fromSql (SqlBool x) = show x
    fromSql (SqlDouble x) = show x
    fromSql (SqlRational x) = show x
    fromSql (SqlLocalDate x) = formatTime defaultTimeLocale
                               (iso8601DateFormat Nothing) x
    fromSql (SqlLocalTimeOfDay x) = formatTime defaultTimeLocale "%T" x
    fromSql (SqlLocalTime x) = formatTime defaultTimeLocale
                               (iso8601DateFormat (Just "%T")) x
    fromSql (SqlZonedTime x) = formatTime defaultTimeLocale
                               (iso8601DateFormat (Just "%T %z")) x
    fromSql (SqlUTCTime x) = formatTime defaultTimeLocale
                               (iso8601DateFormat (Just "%T")) x
    fromSql (SqlDiffTime x) = show ((truncate x)::Integer)
    fromSql (SqlPOSIXTime x) = show ((truncate x)::Integer)
    fromSql (SqlEpochTime x) = show x
    fromSql (SqlTimeDiff x) = show x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to String"

instance SqlType B.ByteString where
    toSql = SqlByteString
    fromSql (SqlByteString x) = x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to ByteString"
    fromSql x = (string2ByteString . fromSql) x

string2ByteString :: String -> B.ByteString
string2ByteString = B.pack . map (toEnum . fromEnum)

instance SqlType Int where
    toSql x = SqlInt32 (fromIntegral x)
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = ord x
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTimeOfDay _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlZonedTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlUTCTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Int"

instance SqlType Int32 where
    toSql = SqlInt32
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral $ ord x
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTimeOfDay _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlZonedTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlUTCTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Int32"

instance SqlType Int64 where
    toSql = SqlInt64
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral $ ord x
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTimeOfDay _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlZonedTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlUTCTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Int64"

instance SqlType Word32 where
    toSql = SqlWord32
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral $ ord x
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTimeOfDay _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlZonedTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlUTCTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Word32"

instance SqlType Word64 where
    toSql = SqlWord64
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral (ord x)
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTimeOfDay _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlLocalTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlZonedTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql y@(SqlUTCTime _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Int64"

instance SqlType Integer where
    toSql = SqlInteger
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = x
    fromSql (SqlChar x) = fromIntegral (ord x)
    fromSql (SqlBool x) = if x then 1 else 0
    fromSql (SqlDouble x) = truncate $ x
    fromSql (SqlRational x) = truncate $ x
    fromSql (SqlLocalDate x) = toModifiedJulianDay x
    fromSql (SqlLocalTimeOfDay x) = fromIntegral . fromEnum . timeOfDayToTime $ x
    fromSql (SqlLocalTime _) = error "fromSql: Impossible to convert SqlLocalTime (LocalTime) to a numeric type."
    fromSql (SqlZonedTime x) = truncate . utcTimeToPOSIXSeconds . zonedTimeToUTC $ x
    fromSql (SqlUTCTime x) = truncate . utcTimeToPOSIXSeconds $ x
    fromSql (SqlDiffTime x) = truncate x
    fromSql (SqlPOSIXTime x) = truncate x
    fromSql (SqlEpochTime x) = x
    fromSql (SqlTimeDiff x) = x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Integer"

instance SqlType Bool where
    toSql = SqlBool
    fromSql (SqlString x) = 
        case map toUpper x of
                           "TRUE" -> True
                           "T" -> True
                           "FALSE" -> False
                           "F" -> False
                           "0" -> False
                           "1" -> True
                           _ -> error $ "fromSql: cannot convert SqlString " 
                                        ++ show x ++ " to Bool"
    fromSql (SqlByteString x) = (fromSql . SqlString . byteString2String) x
    fromSql (SqlInt32 x) = numToBool x
    fromSql (SqlInt64 x) = numToBool x
    fromSql (SqlWord32 x) = numToBool x
    fromSql (SqlWord64 x) = numToBool x
    fromSql (SqlInteger x) = numToBool x
    fromSql (SqlChar x) = numToBool (ord x)
    fromSql (SqlBool x) = x
    fromSql (SqlDouble x) = numToBool x
    fromSql (SqlRational x) = numToBool x
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to Bool"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to Bool"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to Bool"
    fromSql (SqlZonedTime _) = error "fromSql: cannot convert SqlZonedTime to Bool"
    fromSql (SqlUTCTime _) = error "fromSql: cannot convert SqlUTCTime to Bool"
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to Bool"
    fromSql (SqlPOSIXTime _) = error "fromSql: cannot convert SqlPOSIXTime to Bool"
    fromSql (SqlEpochTime x) = numToBool x
    fromSql (SqlTimeDiff x) = numToBool x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Bool"

numToBool :: Num a => a -> Bool
numToBool x = x /= 0

instance SqlType Char where
    toSql = SqlChar
    fromSql (SqlString [x]) = x
    fromSql (SqlByteString x) = (head . byteString2String) x
    fromSql (SqlString _) = error "fromSql: cannot convert SqlString to Char"
    fromSql (SqlInt32 _) = error "fromSql: cannot convert SqlInt32 to Char"
    fromSql (SqlInt64 _) = error "fromSql: cannot convert SqlInt64 to Char"
    fromSql (SqlWord32 _) = error "fromSql: cannot convert SqlWord32 to Char"
    fromSql (SqlWord64 _) = error "fromSql: cannot convert SqlWord64 to Char"
    fromSql (SqlInteger _) = error "fromSql: cannot convert SqlInt to Char"
    fromSql (SqlChar x) = x
    fromSql (SqlBool x) = if x then '1' else '0'
    fromSql (SqlDouble _) = error "fromSql: cannot convert SqlDouble to Char"
    fromSql (SqlRational _) = error "fromSql: cannot convert SqlRational to Char"
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to Char"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to Char"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to Char"
    fromSql (SqlZonedTime _) = error "fromSql: cannot convert SqlZonedTime to Char"
    fromSql (SqlUTCTime _) = error "fromSql: cannot convert SqlUTCTime to Char"
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to Char"
    fromSql (SqlPOSIXTime _) = error "fromSql: cannot convert SqlPOSIXTime to Char"
    fromSql (SqlEpochTime _) = error "fromSql: cannot convert SqlEpochTime to Char"
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to Char"
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Char"

instance SqlType Double where
    toSql = SqlDouble
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral . ord $ x
    fromSql (SqlBool x) = if x then 1.0 else 0.0
    fromSql (SqlDouble x) = x
    fromSql (SqlRational x) = fromRational x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlLocalTimeOfDay x) = fromRational . toRational . timeOfDayToTime $ x
    fromSql (SqlLocalTime _) = error "fromSql: Impossible to convert SqlLocalTime (LocalTime) to a numeric type."
    fromSql (SqlZonedTime x) = fromRational . toRational . utcTimeToPOSIXSeconds . 
                               zonedTimeToUTC $ x
    fromSql (SqlUTCTime x) = fromRational . toRational . utcTimeToPOSIXSeconds $ x
    fromSql (SqlDiffTime x) = fromRational . toRational $ x
    fromSql (SqlPOSIXTime x) = fromRational . toRational $ x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Double"

instance SqlType Rational where
    toSql = SqlRational
    fromSql (SqlString x) = read' x
    fromSql (SqlByteString x) = (read' . byteString2String) x
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar x) = fromIntegral . ord $ x
    fromSql (SqlBool x) = fromIntegral $ ((fromSql (SqlBool x))::Int)
    fromSql (SqlDouble x) = toRational x
    fromSql (SqlRational x) = x
    fromSql y@(SqlLocalDate _) = fromIntegral ((fromSql y)::Integer)
    fromSql (SqlLocalTimeOfDay x) = toRational . timeOfDayToTime $ x
    fromSql (SqlLocalTime _) = error "fromSql: Impossible to convert SqlLocalTime (LocalTime) to a numeric type."
    fromSql (SqlZonedTime x) = toRational . utcTimeToPOSIXSeconds . zonedTimeToUTC $ x
    fromSql (SqlUTCTime x) = toRational . utcTimeToPOSIXSeconds $ x
    fromSql (SqlDiffTime x) = toRational x
    fromSql (SqlPOSIXTime x) = toRational x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Double"

instance SqlType Day where
    toSql = SqlLocalDate
    fromSql (SqlString x) = parseTime' "Day" (iso8601DateFormat Nothing) x
    fromSql y@(SqlByteString _) = fromSql (SqlString (fromSql y))
    fromSql (SqlInt32 x) = ModifiedJulianDay {toModifiedJulianDay = fromIntegral x}
    fromSql (SqlInt64 x) = ModifiedJulianDay {toModifiedJulianDay = fromIntegral x}
    fromSql (SqlWord32 x) = ModifiedJulianDay {toModifiedJulianDay = fromIntegral x}
    fromSql (SqlWord64 x) = ModifiedJulianDay {toModifiedJulianDay = fromIntegral x}
    fromSql (SqlInteger x) = ModifiedJulianDay {toModifiedJulianDay = x}
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to Day"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to Day"
    fromSql (SqlDouble x) = ModifiedJulianDay {toModifiedJulianDay = truncate x}
    fromSql (SqlRational x) = fromSql . SqlDouble . fromRational $ x
    fromSql (SqlLocalDate x) = x
    fromSql (SqlLocalTimeOfDay _) = error "x"
    fromSql (SqlLocalTime x) = localDay x
    fromSql (SqlZonedTime x) = localDay . zonedTimeToLocalTime $ x
    fromSql y@(SqlUTCTime _) = localDay . zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to Day"
    fromSql y@(SqlPOSIXTime _) = localDay . zonedTimeToLocalTime . fromSql $ y
    fromSql y@(SqlEpochTime _) = localDay . zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to Day"
    fromSql (SqlNull) = error "fromSql: cannot convert SqlNull to Day"

instance SqlType TimeOfDay where
    toSql = SqlLocalTimeOfDay
    fromSql (SqlString x) = parseTime' "TimeOfDay" "%T" x
    fromSql y@(SqlByteString _) = fromSql (SqlString (fromSql y))
    fromSql (SqlInt32 x) = timeToTimeOfDay . fromIntegral $ x
    fromSql (SqlInt64 x) = timeToTimeOfDay . fromIntegral $ x
    fromSql (SqlWord32 x) = timeToTimeOfDay . fromIntegral $ x
    fromSql (SqlWord64 x) = timeToTimeOfDay . fromIntegral $ x
    fromSql (SqlInteger x) = timeToTimeOfDay . fromInteger $ x
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to TimeOfDay"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to TimeOfDay"
    fromSql (SqlDouble x) = timeToTimeOfDay . fromIntegral $ 
                            ((truncate x)::Integer)
    fromSql (SqlRational x) = fromSql . SqlDouble . fromRational $ x
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to TimeOfDay"
    fromSql (SqlLocalTimeOfDay x) = x
    fromSql (SqlLocalTime x) = localTimeOfDay x
    fromSql (SqlZonedTime x) = localTimeOfDay . zonedTimeToLocalTime $ x
    fromSql y@(SqlUTCTime _) = localTimeOfDay . zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to TimeOfDay"
    fromSql y@(SqlPOSIXTime _) = localTimeOfDay . zonedTimeToLocalTime . fromSql $ y
    fromSql y@(SqlEpochTime _) = localTimeOfDay . zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to TimeOfDay"
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to Day"

instance SqlType LocalTime where
    toSql = SqlLocalTime
    fromSql (SqlString x) = parseTime' "LocalTime" (iso8601DateFormat (Just "%T")) x
    fromSql y@(SqlByteString _) = fromSql (SqlString (fromSql y))
    fromSql (SqlInt32 _) = error "foo"
    fromSql (SqlInt64 _) = error "foo"
    fromSql (SqlWord32 _) = error "f"
    fromSql (SqlWord64 _) = error "f"
    fromSql (SqlInteger _) = error "fromSql: Impossible to convert SqlInteger to LocalTime"
    fromSql (SqlChar _) = error "f"
    fromSql (SqlBool _) = error "f"
    fromSql (SqlDouble _) = error "f"
    fromSql (SqlRational _) = error "f"
    fromSql (SqlLocalDate _) = error "f"
    fromSql (SqlLocalTimeOfDay _) = error "f"
    fromSql (SqlLocalTime x) = x
    fromSql (SqlZonedTime x) = zonedTimeToLocalTime x
    fromSql y@(SqlUTCTime _) = zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlDiffTime _) = error "f"
    fromSql y@(SqlPOSIXTime _) = zonedTimeToLocalTime . fromSql $ y
    fromSql y@(SqlEpochTime _) = zonedTimeToLocalTime . fromSql $ y
    fromSql (SqlTimeDiff _) = error "f"
    fromSql SqlNull = error "f"

instance SqlType ZonedTime where
    toSql x = SqlZonedTime x
    fromSql (SqlString x) = parseTime' "ZonedTime" (iso8601DateFormat (Just "%T %z")) x
    fromSql (SqlByteString x) = fromSql (SqlString (byteString2String x))
    fromSql (SqlInt32 x) = fromSql (SqlInteger (fromIntegral x))
    fromSql (SqlInt64 x) = fromSql (SqlInteger (fromIntegral x))
    fromSql (SqlWord32 x) = fromSql (SqlInteger (fromIntegral x))
    fromSql (SqlWord64 x) = fromSql (SqlInteger (fromIntegral x))
    fromSql y@(SqlInteger _) = utcToZonedTime utc (fromSql y)
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to ZonedTime"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to ZonedTime"
    fromSql y@(SqlDouble _) = utcToZonedTime utc (fromSql y)
    fromSql y@(SqlRational _) = utcToZonedTime utc (fromSql y)
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to ZonedTime"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to ZonedTime"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to ZonedTime"
    fromSql (SqlZonedTime x) = x
    fromSql (SqlUTCTime x) = utcToZonedTime utc x
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to ZonedTime"
    fromSql y@(SqlPOSIXTime _) = utcToZonedTime utc (fromSql y)
    fromSql y@(SqlEpochTime _) = utcToZonedTime utc (fromSql y)
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to ZonedTime"
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to ZonedTime"

instance SqlType UTCTime where
    toSql = SqlUTCTime
    fromSql (SqlString x) = parseTime' "UTCTime" (iso8601DateFormat (Just "%T")) x
    fromSql (SqlByteString x) = fromSql (SqlString (byteString2String x))
    fromSql y@(SqlInt32 _) = posixSecondsToUTCTime . fromSql $ y
    fromSql y@(SqlInt64 _) = posixSecondsToUTCTime . fromSql $ y
    fromSql y@(SqlWord32 _) = posixSecondsToUTCTime . fromSql $ y
    fromSql y@(SqlWord64 _) = posixSecondsToUTCTime . fromSql $ y
    fromSql y@(SqlInteger _) = posixSecondsToUTCTime . fromSql $ y
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to UTCTime"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to UTCTime"
    fromSql y@(SqlDouble _) = posixSecondsToUTCTime . fromSql $ y
    fromSql y@(SqlRational _) = posixSecondsToUTCTime . fromSql $ y
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to UTCTime"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to UTCTime"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to UTCTime"
    fromSql (SqlZonedTime x) = zonedTimeToUTC x
    fromSql (SqlUTCTime x) = x
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to UTCTime; did you mean SqlPOSIXTime?"
    fromSql (SqlPOSIXTime x) = posixSecondsToUTCTime x
    fromSql y@(SqlEpochTime _) = posixSecondsToUTCTime . fromSql $ y
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to UTCTime; did you mean SqlPOSIXTime?"
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to UTCTime"

instance SqlType NominalDiffTime where
    toSql = SqlDiffTime
    fromSql (SqlString x) = fromInteger (read' x)
    fromSql (SqlByteString x) = fromInteger ((read' . byteString2String) x)
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to NominalDiffTime"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to NominalDiffTime"
    fromSql (SqlDouble x) = fromRational . toRational $ x
    fromSql (SqlRational x) = fromRational x
    fromSql (SqlLocalDate x) = fromIntegral . (\y -> y * 60 * 60 * 24) . 
                               toModifiedJulianDay $ x
    fromSql (SqlLocalTimeOfDay x) = fromRational . toRational . timeOfDayToTime $ x
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to NominalDiffTime"
    fromSql (SqlZonedTime x) = utcTimeToPOSIXSeconds . zonedTimeToUTC $ x
    fromSql (SqlUTCTime x) = utcTimeToPOSIXSeconds x
    fromSql (SqlDiffTime x) = x
    fromSql (SqlPOSIXTime x) = x
    fromSql (SqlEpochTime x) = fromIntegral x
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to NominalDiffTime"

instance SqlType ST.ClockTime where
    toSql (ST.TOD x y) = SqlPOSIXTime . fromRational $ 
                                        fromInteger x + fromRational (y % 1000000000000)
    fromSql (SqlString x) = ST.TOD (read' x) 0
    fromSql (SqlByteString x) = ST.TOD ((read' . byteString2String) x) 0
    fromSql (SqlInt32 x) = ST.TOD (fromIntegral x) 0
    fromSql (SqlInt64 x) = ST.TOD (fromIntegral x) 0
    fromSql (SqlWord32 x) = ST.TOD (fromIntegral x) 0
    fromSql (SqlWord64 x) = ST.TOD (fromIntegral x) 0
    fromSql (SqlInteger x) = ST.TOD x 0
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to ClockTime"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to ClockTime"
    fromSql (SqlDouble x) = ST.TOD (truncate x) 0
    fromSql (SqlRational x) = ST.TOD (truncate x) 0
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to ClockTime"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to ClockTime"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to ClockTime"
    fromSql y@(SqlZonedTime _) = ST.TOD (fromSql y) 0
    fromSql y@(SqlUTCTime _) = ST.TOD (fromSql y) 0
    fromSql (SqlDiffTime _) = error "fromSql: cannot convert SqlDiffTime to ClockTime"
    fromSql y@(SqlPOSIXTime _) = ST.TOD (fromSql y) 0
    fromSql (SqlEpochTime x) = ST.TOD x 0
    fromSql (SqlTimeDiff _) = error "fromSql: cannot convert SqlTimeDiff to ClockTime"
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to ClockTime"

instance SqlType ST.TimeDiff where
    toSql x = SqlDiffTime . fromIntegral . timeDiffToSecs $ x
    fromSql (SqlString x) = secs2td (read' x)
    fromSql (SqlByteString x) = secs2td ((read' . byteString2String) x)
    fromSql (SqlInt32 x) = secs2td (fromIntegral x)
    fromSql (SqlInt64 x) = secs2td (fromIntegral x)
    fromSql (SqlWord32 x) = secs2td (fromIntegral x)
    fromSql (SqlWord64 x) = secs2td (fromIntegral x)
    fromSql (SqlInteger x) = secs2td x
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to TimeDiff"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to TimeDiff"
    fromSql (SqlDouble x) = secs2td (truncate x)
    fromSql (SqlRational x) = secs2td (truncate x)
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to TimeDiff"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to TimeDiff"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to TimeDiff"
    fromSql (SqlZonedTime _) = error "fromSql: cannot convert SqlZonedTime to TimeDiff"
    fromSql (SqlUTCTime _) = error "fromSql: cannot convert SqlUTCTime to TimeDiff"
    fromSql (SqlPOSIXTime _) = error "fromSql: cannot convert SqlPOSIXTime to TimeDiff"
    fromSql (SqlDiffTime x) = secs2td (truncate x)
    fromSql (SqlEpochTime _) = error "fromSql: cannot convert SqlEpochTime to TimeDiff"
    fromSql (SqlTimeDiff x) = secs2td x
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to TimeDiff"

instance SqlType DiffTime where
    toSql x = SqlDiffTime . fromRational . toRational $ x
    fromSql (SqlString x) = fromInteger (read' x)
    fromSql (SqlByteString x) = fromInteger ((read' . byteString2String) x)
    fromSql (SqlInt32 x) = fromIntegral x
    fromSql (SqlInt64 x) = fromIntegral x
    fromSql (SqlWord32 x) = fromIntegral x
    fromSql (SqlWord64 x) = fromIntegral x
    fromSql (SqlInteger x) = fromIntegral x
    fromSql (SqlChar _) = error "fromSql: cannot convert SqlChar to DiffTime"
    fromSql (SqlBool _) = error "fromSql: cannot convert SqlBool to DiffTime"
    fromSql (SqlDouble x) = fromIntegral ((truncate x)::Integer)
    fromSql (SqlRational x) = fromIntegral ((truncate x)::Integer)
    fromSql (SqlLocalDate _) = error "fromSql: cannot convert SqlLocalDate to DiffTime"
    fromSql (SqlLocalTimeOfDay _) = error "fromSql: cannot convert SqlLocalTimeOfDay to DiffTime"
    fromSql (SqlLocalTime _) = error "fromSql: cannot convert SqlLocalTime to DiffTime"
    fromSql (SqlZonedTime _) = error "fromSql: cannot convert SqlZonedTime to DiffTime"
    fromSql (SqlUTCTime _) = error "fromSql: cannot convert SqlUTCTime to DiffTime"
    fromSql (SqlDiffTime x) = fromRational . toRational $ x
    fromSql (SqlPOSIXTime _) = error "fromSql: cannot convert SqlPOSIXTime to DiffTime"
    fromSql (SqlEpochTime _) = error "fromSql: cannot convert SqlEpochTime to DiffTime"
    fromSql (SqlTimeDiff x) = fromIntegral x
    fromSql SqlNull = error "fromSql: cannot convert SqlNull to DiffTime"

instance SqlType ST.CalendarTime where
    toSql x = toSql (ST.toClockTime x)
    fromSql = ST.toUTCTime . fromSql

instance (SqlType a) => SqlType (Maybe a) where
    toSql Nothing = SqlNull
    toSql (Just a) = toSql a
    fromSql SqlNull = Nothing
    fromSql x = Just (fromSql x)

byteString2String :: B.ByteString -> String
byteString2String = map (toEnum . fromEnum) . B.unpack

secs2td :: Integer -> ST.TimeDiff
secs2td x = ST.diffClockTimes (ST.TOD x 0) (ST.TOD 0 0)


-- | Read a value from a string, and give an informative message
--   if it fails.
read' :: (Typeable a,Read a) => String -> a
read' s = ret
  where ret = case reads s of
                  [(x,"")] -> x
                  _ -> error $ "fromSql: Cannot read " ++ show s 
                               ++ " as " ++ t ++ "."
        t = show (typeOf ret)

parseTime' :: ParseTime t => String -> String -> String -> t
parseTime' t fmtstr inpstr = ret
    where ret = case parseTime defaultTimeLocale fmtstr inpstr of
                  Nothing -> error $ "fromSql: Cannot read " ++ show inpstr ++ " as " ++ 
                             t ++ " using default format string " ++ show fmtstr ++ "."
                  Just x -> x

--------------
-- The following function copied from MissingH.Time.hs

{- | Converts the given timeDiff to the number of seconds it represents.

Uses the same algorithm as normalizeTimeDiff in GHC. -}
timeDiffToSecs :: ST.TimeDiff -> Integer
timeDiffToSecs td =
    (fromIntegral $ ST.tdSec td) +
    60 * ((fromIntegral $ ST.tdMin td) +
          60 * ((fromIntegral $ ST.tdHour td) +
                24 * ((fromIntegral $ ST.tdDay td) +
                      30 * ((fromIntegral $ ST.tdMonth td) +
                            365 * (fromIntegral $ ST.tdYear td)))))