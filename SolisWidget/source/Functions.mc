class Conversion {

    function StringToByteArray(plain_text) {
        return StringUtil.convertEncodedString(plain_text, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function ByteArrayToHexString(byte_array) {
        return StringUtil.convertEncodedString(byte_array, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function ByteArrayToBase64String(byte_array) {
        return StringUtil.convertEncodedString(byte_array, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function Utf8ArrayToString(utf8Array) {
        return StringUtil.utf8ArrayToString(utf8Array);
    }
}

class Hash {

    function NewSha256HashObject() {
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA256
        });
    }

    function NewSha1HashObject() {
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA1
        });
    }

    function NewMd5HashObject() {
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_MD5
        });
    }

    function ComputeHash(hash, byte_array) {
        hash.update(byte_array);
        return hash.digest();
    }
}

class DateTime {

    function GetDateUTCString() {

        var today = Time.Gregorian.info(Time.now(), Time.FORMAT_LONG);
        //"Fri, 26 Jul 2019 06:00:46 GMT"
        var dateString = Lang.format(
            "$1$, $2$ $3$ $4$ $5$:$6$:$7$ GMT",
            [
                today.day_of_week,
                today.day,
                today.month,
                today.year,
                today.hour,
                today.min,
                today.sec
            ]);
        return dateString;
    }

    function toMoment(string){
        //System.println(string);
        return Time.Gregorian.moment({
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        });
    }
}