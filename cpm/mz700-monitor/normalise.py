"""Translate the published monitor syntax; original-byte equality is checked separately."""
import ast,re

def normalise(source):
 lines=[]
 for line in source.splitlines():
  if re.match(r'\s*CPU\s+',line,re.I):continue
  # Expand quoted characters/strings before discarding comments. Protect semicolons
  # inside strings; an AF' register token is not a quoted character literal.
  code=re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])\'',lambda m:','.join(str(ord(c)) for c in ast.literal_eval(m[0])),line)
  code=code.split(';',1)[0]
  code=re.sub(r'\b([0-9][0-9a-f]*)h\b',lambda m:'0x'+m[1],code,flags=re.I)
  code=re.sub(r'\bDB\s+(\d+)\s+DUP\s+\?',r'DS \1',code,flags=re.I)
  code=re.sub(r'\bDB\s+\?',r'DS 1',code,flags=re.I)
  lines.append(code.expandtabs(8))
 return '\n'.join(lines)+'\n'
