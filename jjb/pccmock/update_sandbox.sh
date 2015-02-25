set -exu

echo "## prepare file to show templates"
CWD=`pwd`
DIRNAME="${CWD%/*}"
FILE_TMPL="show_jjb_templates.sh"
rm -f "$FILE_TMPL"
list=`ls -x | tr -s '\t\n' ' '`
for f in `ls -x | tr -s '\t\n' ' '`
do
  diff -ur "/dev/null" "$f" >> "$FILE_TMPL" && true
done
sed -i 's/^/# /' "$FILE_TMPL"

echo "## prepare file to transfer binary files"
FILE_TRANS="unpack_files.sh"
rm -f "$FILE_TRANS"
cat >> "$FILE_TRANS" << END
python -c "
import binascii
END
for f in `cat files_to_transfer.txt | tr -s '\t\n' ' '`
do
  cat >> "$FILE_TRANS" << END
with open('$f', 'wb') as f:
    f.write(binascii.unhexlify('''
END
  python >> "$FILE_TRANS" << END
import binascii
with open('$f', 'rb') as f:
    print binascii.hexlify(f.read())

END
  cat >> "$FILE_TRANS" << END
'''[1:-1]))

END
done
cat >> "$FILE_TRANS" << END
"
END
jenkins-jobs --conf "../../jenkins.ini" update "."
rm "$FILE_TRANS"
rm "$FILE_TMPL"