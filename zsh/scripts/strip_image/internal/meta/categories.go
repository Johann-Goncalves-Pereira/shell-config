package meta

import "strings"

const (
	CatCamera     = "Camera Hardware & Device Data"
	CatExposure   = "Exposure & Capture Settings"
	CatGeo        = "Geolocation & Environment"
	CatTime       = "Time & Identity Basics"
	CatDesc       = "Description & Content Context"
	CatCopyright  = "Copyright, Ownership & Licensing"
	CatSoftware   = "Software, Edits & Version Control"
	CatAI         = "AI, Machine Learning & Automation"
	CatFileSystem = "File System Properties"
	CatOther      = "Other"
)

var tagCategory = map[string]string{
	"make": CatCamera, "manufacturer": CatCamera, "model": CatCamera,
	"serialnumber": CatCamera, "cameraserialnumber": CatCamera,
	"lensmodel": CatCamera, "lensmake": CatCamera, "lensmanufacturer": CatCamera,
	"lensserialnumber": CatCamera, "firmwareversion": CatCamera,
	"uniqueid": CatCamera, "deviceuniqueid": CatCamera, "uniquecameramodel": CatCamera,
	"sensortype": CatCamera, "digitalzoomratio": CatCamera, "lensinfo": CatCamera,
	"lensid": CatCamera, "bodyid": CatCamera,

	"exposuretime": CatExposure, "shutterspeed": CatExposure, "shutterspeedvalue": CatExposure,
	"fnumber": CatExposure, "aperture": CatExposure, "aperturevalue": CatExposure,
	"iso": CatExposure, "isospeedratings": CatExposure, "isopeed": CatExposure,
	"focallength": CatExposure, "focallengthin35mmformat": CatExposure,
	"focallengthin35mmfilm": CatExposure,
	"exposureprogram": CatExposure, "exposurecompensation": CatExposure,
	"exposurebiasvalue": CatExposure, "meteringmode": CatExposure,
	"flash": CatExposure, "whitebalance": CatExposure, "colorspace": CatExposure,
	"lightsource": CatExposure, "subjectdistance": CatExposure, "gaincontrol": CatExposure,
	"contrast": CatExposure, "saturation": CatExposure, "sharpness": CatExposure,

	"gpslatitude": CatGeo, "gpslongitude": CatGeo, "gpsaltitude": CatGeo,
	"gpslatituderef": CatGeo, "gpslongituderef": CatGeo, "gpsaltituderef": CatGeo,
	"gpsdatetime": CatGeo, "gpstimestamp": CatGeo, "gpsdatestamp": CatGeo,
	"gpssatellites": CatGeo, "gpsstatus": CatGeo, "gpsmapdatum": CatGeo,
	"gpsspeed": CatGeo, "gpsimgdirection": CatGeo, "gpsdestbearing": CatGeo,
	"gpsposition": CatGeo, "city": CatGeo, "state": CatGeo, "country": CatGeo,
	"countrycode": CatGeo, "sublocation": CatGeo, "location": CatGeo,
	"locationname": CatGeo, "locationcreatedcity": CatGeo,
	"locationcreatedprovince": CatGeo, "locationcreatedcountryname": CatGeo,

	"datetimeoriginal": CatTime, "createdate": CatTime, "modifydate": CatTime,
	"subsectime": CatTime, "subsectimeoriginal": CatTime, "subsectimedigitized": CatTime,
	"offsettime": CatTime, "offsettimeoriginal": CatTime, "offsettimedigitized": CatTime,
	"orientation": CatTime, "imagewidth": CatTime, "imageheight": CatTime,
	"exifimagewidth": CatTime, "exifimageheight": CatTime,
	"xresolution": CatTime, "yresolution": CatTime, "resolutionunit": CatTime,

	"headline": CatDesc, "title": CatDesc, "objectname": CatDesc,
	"caption": CatDesc, "imagedescription": CatDesc, "description": CatDesc,
	"alttextaccessibility": CatDesc, "keywords": CatDesc, "subject": CatDesc,
	"category": CatDesc, "supplementalcategories": CatDesc, "scenetype": CatDesc,
	"scene": CatDesc, "rating": CatDesc, "urgency": CatDesc,
	"usercomment": CatDesc, "comment": CatDesc, "notes": CatDesc,

	"creator": CatCopyright, "artist": CatCopyright, "byline": CatCopyright,
	"authorsposition": CatCopyright, "creatorworkemail": CatCopyright,
	"creatorworktelephone": CatCopyright, "creatorworkurl": CatCopyright,
	"creatoraddress": CatCopyright, "copyright": CatCopyright,
	"copyrightnotice": CatCopyright, "copyrightstatus": CatCopyright,
	"usageterms": CatCopyright, "rightsusageterms": CatCopyright,
	"license": CatCopyright, "licensorurl": CatCopyright, "webstatement": CatCopyright,
	"credit": CatCopyright, "provider": CatCopyright, "source": CatCopyright,
	"modelreleasestatus": CatCopyright, "propertyreleasestatus": CatCopyright,
	"instructions": CatCopyright, "specialinstructions": CatCopyright,

	"software": CatSoftware, "historysoftwareagent": CatSoftware,
	"history": CatSoftware, "derivedfrom": CatSoftware,
	"documentid": CatSoftware, "originaldocumentid": CatSoftware,
	"instanceid": CatSoftware, "historyaction": CatSoftware,
	"historyparameters": CatSoftware, "photoshop": CatSoftware,
	"profiledescription": CatSoftware, "iccprofile": CatSoftware,

	"aiprompt": CatAI, "prompt": CatAI, "negativeprompt": CatAI,
	"aimodel": CatAI, "modelhash": CatAI, "seed": CatAI,
	"sampler": CatAI, "cfgscale": CatAI, "steps": CatAI,
	"objectnameai": CatAI, "regioninfo": CatAI, "personinimage": CatAI,
	"c2pa": CatAI, "contentcredentials": CatAI, "claim_generator": CatAI,
}

var skipTags = map[string]struct{}{
	"sourcefile": {}, "directory": {}, "filename": {}, "filesize": {},
	"filemodifydate": {}, "fileaccessdate": {}, "fileinodechangedate": {},
	"filepermissions": {}, "filetype": {}, "filetypename": {},
	"mimetype": {}, "exiftoolversion": {},
}

func categoryFor(group, tag string) string {
	g := strings.ToLower(group)
	t := strings.ToLower(strings.ReplaceAll(tag, " ", ""))
	t = strings.ReplaceAll(t, "-", "")
	t = strings.ReplaceAll(t, "_", "")
	if g == "gps" || strings.HasPrefix(t, "gps") {
		return CatGeo
	}
	if strings.Contains(g, "c2pa") || strings.Contains(t, "c2pa") {
		return CatAI
	}
	if cat, ok := tagCategory[t]; ok {
		return cat
	}
	switch g {
	case "makernotes":
		return CatCamera
	case "iptc":
		return CatDesc
	case "icc_profile":
		return CatSoftware
	}
	return CatOther
}
