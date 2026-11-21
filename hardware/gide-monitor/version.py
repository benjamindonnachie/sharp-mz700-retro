"""Release identity shared by the physical ROM and card RAM monitor."""
VERSION = '0.1.0'
BUILD_DATE = '2026-11-18'
TITLE = 'GIDE BOOT MONITOR'
BANNER = (TITLE+' V'+VERSION+'\r').encode('ascii')
DATE_LINE = (BUILD_DATE+'\r').encode('ascii')
assert len(BANNER) <= 25
