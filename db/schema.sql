create table sites (
	id             integer        primary key autoincrement,
	parent         integer        null                     check(parent is null or parent>0),

	code           varchar        not null                 check(length(code) >= 2   and length(code) <= 50),
	link_domain    varchar        not null default ''      check(link_domain = '' or (length(link_domain) >= 4 and length(link_domain) <= 255)),
	cname          varchar        null                     check(cname is null or (length(cname) >= 4 and length(cname) <= 255)),
	cname_setup_at timestamp      default null             check(cname_setup_at = strftime('%Y-%m-%d %H:%M:%S', cname_setup_at)),
	plan           varchar        not null                 check(plan in ('personal', 'personalplus', 'business', 'businessplus', 'child', 'custom')),
	stripe         varchar        null,
	settings       varchar        not null,
	received_data  int            not null default 0,

	state          varchar        not null default 'a'     check(state in ('a', 'd')),
	created_at     timestamp      not null                 check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),
	updated_at     timestamp                               check(updated_at = strftime('%Y-%m-%d %H:%M:%S', updated_at))
);
create unique index "sites#code" on sites(lower(code));

create table users (
	id             integer        primary key autoincrement,
	site           integer        not null                 check(site > 0),

	password       blob           default null,
	totp_enabled   integer        not null default 0,
	totp_secret    blob,
	email          varchar        not null                 check(length(email) > 5 and length(email) <= 255),
	email_verified int            not null default 0,
	role           varchar        not null default ''      check(role in ('', 'a')),
	login_at       timestamp      null                     check(login_at = strftime('%Y-%m-%d %H:%M:%S', login_at)),
	login_request  varchar        null,
	login_token    varchar        null,
	csrf_token     varchar        null,
	email_token    varchar        null,
	seen_updates_at timestamp     not null default '1970-01-01 00:00:00' check(seen_updates_at = strftime('%Y-%m-%d %H:%M:%S', seen_updates_at)),
	reset_at       timestamp      null,

	created_at     timestamp      not null                 check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),
	updated_at     timestamp                               check(updated_at = strftime('%Y-%m-%d %H:%M:%S', updated_at)),

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create        index "users#site"          on users(site);
create unique index "users#site#email"    on users(site, lower(email));

create table api_tokens (
	api_token_id   integer        primary key autoincrement,
	site_id        integer        not null,
	user_id        integer        not null,
	name           varchar        not null,
	token          varchar        not null    check(length(token) > 10),
	permissions    jsonb          not null,
	created_at     timestamp      not null    check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),

	foreign key (site_id) references sites(id) on delete restrict on update restrict,
	foreign key (user_id) references users(id) on delete restrict on update restrict
);
create unique index "api_tokens#site_id#token" on api_tokens(site_id, token);

create table hits (
	id             integer        primary key autoincrement,
	site           integer        not null                 check(site > 0),
	session        integer        default null,

	path           varchar        not null,
	title          varchar        not null default '',
	event          int            default 0,
	bot            int            default 0,
	ref            varchar        not null,
	ref_scheme     varchar        null                     check(ref_scheme in ('h', 'g', 'o', 'c')),
	browser        varchar        not null,
	size           varchar        not null default '',
	location       varchar        not null default '',
	first_visit    int            default 0,

	created_at     timestamp      not null                 check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at))
);
create index "hits#site#bot#created_at"      on hits(site, bot, created_at);
create index "hits#site#bot#path#created_at" on hits(site, bot, lower(path), created_at);

create table sessions (
	id             integer        primary key autoincrement,
	site           integer        not null                 check(site > 0),
	hash           blob           null,
	created_at     timestamp      not null,
	last_seen      timestamp      not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create unique index "sessions#site#hash" on sessions(site, hash);
create        index "sessions#last_seen" on sessions(last_seen);

create table session_paths (
	session        integer        not null,
	path           varchar        not null,

	foreign key (session) references sessions(id) on delete cascade on update cascade
);
create index "session_paths#session#path" on session_paths(session, lower(path));

create table session_salts (
	previous    int        not null,
	salt        varchar    not null,
	created_at  timestamp  not null
);

create table hit_stats (
	site           integer        not null                 check(site > 0),

	day            date           not null                 check(day = strftime('%Y-%m-%d', day)),
	path           varchar        not null,
	title          varchar        not null default '',
	stats          varchar        not null,
	stats_unique   varchar        not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create index "hit_stats#site#day" on hit_stats(site, day);

create table hit_counts (
	site          int        not null check(site>0),
	path          varchar    not null,
	title         varchar    not null,
	event         integer    not null default 0,
	hour          timestamp  not null check(hour = strftime('%Y-%m-%d %H:%M:%S', hour)),
	total         int        not null,
	total_unique  int        not null,

	constraint "hit_counts2#site#path#hour" unique(site, path, hour) on conflict replace
);
create index "hit_counts#site#hour" on hit_counts(site, hour);

create table ref_counts (
	site          int        not null check(site>0),
	path          varchar    not null,
	ref           varchar    not null,
	ref_scheme    varchar    null,
	hour          timestamp  not null check(hour = strftime('%Y-%m-%d %H:%M:%S', hour)),
	total         int        not null,
	total_unique  int        not null,

	constraint "ref_counts#site#path#ref#hour" unique(site, path, ref, hour) on conflict replace
);
create index "ref_counts#site#hour" on ref_counts(site, hour);

create table browser_stats (
	site           integer        not null                 check(site > 0),

	day            date           not null                 check(day = strftime('%Y-%m-%d', day)),
	browser        varchar        not null,
	version        varchar        not null,
	count          int            not null,
	count_unique   int            not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create index "browser_stats#site#day#browser" on browser_stats(site, day, browser);

create table system_stats (
	site           integer        not null                 check(site > 0),

	day            date           not null                 check(day = strftime('%Y-%m-%d', day)),
	system         varchar        not null,
	version        varchar        not null,
	count          int            not null,
	count_unique   int            not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create index "system_stats#site#day"        on system_stats(site, day);
create index "system_stats#site#day#system" on system_stats(site, day, system);

create table location_stats (
	site           integer        not null                 check(site > 0),

	day            date           not null                 check(day = strftime('%Y-%m-%d', day)),
	location       varchar        not null,
	count          int            not null,
	count_unique   int            not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create index "location_stats#site#day#location" on location_stats(site, day, location);

create table size_stats (
	site           integer        not null                 check(site > 0),

	day            date           not null                 check(day = strftime('%Y-%m-%d', day)),
	width          int            not null,
	count          int            not null,
	count_unique   int            not null,

	foreign key (site) references sites(id) on delete restrict on update restrict
);
create index "size_stats#site#day#width" on size_stats(site, day, width);

create table iso_3166_1 (
	name   varchar,
	alpha2 varchar
);
create index "iso_3166_1#alpha2" on iso_3166_1(alpha2);
insert into iso_3166_1 (name, alpha2) values
	('(unknown)', ''),

	('Ascension Island', 'AC'),
	('Andorra', 'AD'),
	('United Arab Emirates', 'AE'),
	('Afghanistan', 'AF'),
	('Antigua and Barbuda', 'AG'),
	('Anguilla', 'AI'),
	('Albania', 'AL'),
	('Armenia', 'AM'),
	('Netherlands Antilles', 'AN'),
	('Angola', 'AO'),
	('Antarctica', 'AQ'),
	('Argentina', 'AR'),
	('American Samoa', 'AS'),
	('Austria', 'AT'),
	('Australia', 'AU'),
	('Aruba', 'AW'),
	('Åland Islands', 'AX'),
	('Azerbaijan', 'AZ'),
	('Bosnia and Herzegovina', 'BA'),
	('Barbados', 'BB'),
	('Bangladesh', 'BD'),
	('Belgium', 'BE'),
	('Burkina Faso', 'BF'),
	('Bulgaria', 'BG'),
	('Bahrain', 'BH'),
	('Burundi', 'BI'),
	('Benin', 'BJ'),
	('Saint Barthélemy', 'BL'),
	('Bermuda', 'BM'),
	('Brunei Darussalam', 'BN'),
	('Bolivia', 'BO'),
	('Bonaire, Sint Eustatius and Saba', 'BQ'),
	('Brazil', 'BR'),
	('Bahamas', 'BS'),
	('Bhutan', 'BT'),
	('Burma', 'BU'),
	('Bouvet Island', 'BV'),
	('Botswana', 'BW'),
	('Belarus', 'BY'),
	('Belize', 'BZ'),
	('Canada', 'CA'),
	('Cocos (Keeling) Islands', 'CC'),
	('Democratic Republic of thje Congo', 'CD'),
	('Central African Republic', 'CF'),
	('Congo', 'CG'),
	('Switzerland', 'CH'),
	('Côte d''Ivoire', 'CI'),
	('Cook Islands', 'CK'),
	('Chile', 'CL'),
	('Cameroon', 'CM'),
	('China', 'CN'),
	('Colombia', 'CO'),
	('Clipperton Island', 'CP'),
	('Costa Rica', 'CR'),
	('Serbia and Montenegro', 'CS'),
	('Cuba', 'CU'),
	('Cabo Verde', 'CV'),
	('Curaçao', 'CW'),
	('Christmas Island', 'CX'),
	('Cyprus', 'CY'),
	('Czechia', 'CZ'),
	('Germany', 'DE'),
	('Diego Garcia', 'DG'),
	('Djibouti', 'DJ'),
	('Denmark', 'DK'),
	('Dominica', 'DM'),
	('Dominican Republic', 'DO'),
	('Benin', 'DY'),
	('Algeria', 'DZ'),
	('Ceuta, Melilla', 'EA'),
	('Ecuador', 'EC'),
	('Estonia', 'EE'),
	('Egypt', 'EG'),
	('Western Sahara', 'EH'),
	('Eritrea', 'ER'),
	('Spain', 'ES'),
	('Ethiopia', 'ET'),
	('European Union', 'EU'),
	('Estonia', 'EW'),
	('Eurozone', 'EZ'),
	('Finland', 'FI'),
	('Fiji', 'FJ'),
	('Falkland Islands (Malvinas)', 'FK'),
	('Liechtenstein', 'FL'),
	('Micronesia', 'FM'),
	('Faroe Islands', 'FO'),
	('France', 'FR'),
	('France, Metropolitan', 'FX'),
	('Gabon', 'GA'),
	('United Kingdom', 'GB'),
	('Grenada', 'GD'),
	('Georgia', 'GE'),
	('French Guiana', 'GF'),
	('Guernsey', 'GG'),
	('Ghana', 'GH'),
	('Gibraltar', 'GI'),
	('Greenland', 'GL'),
	('Gambia', 'GM'),
	('Guinea', 'GN'),
	('Guadeloupe', 'GP'),
	('Equatorial Guinea', 'GQ'),
	('Greece', 'GR'),
	('South Georgia and the South Sandwich Islands', 'GS'),
	('Guatemala', 'GT'),
	('Guam', 'GU'),
	('Guinea-Bissau', 'GW'),
	('Guyana', 'GY'),
	('Hong Kong', 'HK'),
	('Heard Island and McDonald Islands', 'HM'),
	('Honduras', 'HN'),
	('Croatia', 'HR'),
	('Haiti', 'HT'),
	('Hungary', 'HU'),
	('Canary Islands', 'IC'),
	('Indonesia', 'ID'),
	('Ireland', 'IE'),
	('Israel', 'IL'),
	('Isle of Man', 'IM'),
	('India', 'IN'),
	('British Indian Ocean Territory', 'IO'),
	('Iraq', 'IQ'),
	('Iran', 'IR'),
	('Iceland', 'IS'),
	('Italy', 'IT'),
	('Jamaica', 'JA'),
	('Jersey', 'JE'),
	('Jamaica', 'JM'),
	('Jordan', 'JO'),
	('Japan', 'JP'),
	('Kenya', 'KE'),
	('Kyrgyzstan', 'KG'),
	('Cambodia', 'KH'),
	('Kiribati', 'KI'),
	('Comoros', 'KM'),
	('Saint Kitts and Nevis', 'KN'),
	('North Korea', 'KP'),
	('South Korea', 'KR'),
	('Kuwait', 'KW'),
	('Cayman Islands', 'KY'),
	('Kazakhstan', 'KZ'),
	('Lao People''s Democratic Republic', 'LA'),
	('Lebanon', 'LB'),
	('Saint Lucia', 'LC'),
	('Libya Fezzan', 'LF'),
	('Liechtenstein', 'LI'),
	('Sri Lanka', 'LK'),
	('Liberia', 'LR'),
	('Lesotho', 'LS'),
	('Lithuania', 'LT'),
	('Luxembourg', 'LU'),
	('Latvia', 'LV'),
	('Libya', 'LY'),
	('Morocco', 'MA'),
	('Monaco', 'MC'),
	('Moldova, Republic of', 'MD'),
	('Montenegro', 'ME'),
	('Saint Martin (French part)', 'MF'),
	('Madagascar', 'MG'),
	('Marshall Islands', 'MH'),
	('North Macedonia', 'MK'),
	('Mali', 'ML'),
	('Myanmar', 'MM'),
	('Mongolia', 'MN'),
	('Macao', 'MO'),
	('Northern Mariana Islands', 'MP'),
	('Martinique', 'MQ'),
	('Mauritania', 'MR'),
	('Montserrat', 'MS'),
	('Malta', 'MT'),
	('Mauritius', 'MU'),
	('Maldives', 'MV'),
	('Malawi', 'MW'),
	('Mexico', 'MX'),
	('Malaysia', 'MY'),
	('Mozambique', 'MZ'),
	('Namibia', 'NA'),
	('New Caledonia', 'NC'),
	('Niger', 'NE'),
	('Norfolk Island', 'NF'),
	('Nigeria', 'NG'),
	('Nicaragua', 'NI'),
	('Netherlands', 'NL'),
	('Norway', 'NO'),
	('Nepal', 'NP'),
	('Nauru', 'NR'),
	('Neutral Zone', 'NT'),
	('Niue', 'NU'),
	('New Zealand', 'NZ'),
	('Oman', 'OM'),
	('Escape code', 'OO'),
	('Panama', 'PA'),
	('Peru', 'PE'),
	('French Polynesia', 'PF'),
	('Papua New Guinea', 'PG'),
	('Philippines', 'PH'),
	('Philippines', 'PI'),
	('Pakistan', 'PK'),
	('Poland', 'PL'),
	('Saint Pierre and Miquelon', 'PM'),
	('Pitcairn', 'PN'),
	('Puerto Rico', 'PR'),
	('Palestine, State of', 'PS'),
	('Portugal', 'PT'),
	('Palau', 'PW'),
	('Paraguay', 'PY'),
	('Qatar', 'QA'),
	('Argentina', 'RA'),
	('Bolivia; Botswana', 'RB'),
	('China', 'RC'),
	('Réunion', 'RE'),
	('Haiti', 'RH'),
	('Indonesia', 'RI'),
	('Lebanon', 'RL'),
	('Madagascar', 'RM'),
	('Niger', 'RN'),
	('Romania', 'RO'),
	('Philippines', 'RP'),
	('Serbia', 'RS'),
	('Russian Federation', 'RU'),
	('Rwanda', 'RW'),
	('Saudi Arabia', 'SA'),
	('Solomon Islands', 'SB'),
	('Seychelles', 'SC'),
	('Sudan', 'SD'),
	('Sweden', 'SE'),
	('Finland', 'SF'),
	('Singapore', 'SG'),
	('Saint Helena, Ascension and Tristan da Cunha', 'SH'),
	('Slovenia', 'SI'),
	('Svalbard and Jan Mayen', 'SJ'),
	('Slovakia', 'SK'),
	('Sierra Leone', 'SL'),
	('San Marino', 'SM'),
	('Senegal', 'SN'),
	('Somalia', 'SO'),
	('Suriname', 'SR'),
	('South Sudan', 'SS'),
	('Sao Tome and Principe', 'ST'),
	('USSR', 'SU'),
	('El Salvador', 'SV'),
	('Sint Maarten (Dutch part)', 'SX'),
	('Syrian Arab Republic', 'SY'),
	('Eswatini', 'SZ'),
	('Tristan da Cunha', 'TA'),
	('Turks and Caicos Islands', 'TC'),
	('Chad', 'TD'),
	('French Southern Territories', 'TF'),
	('Togo', 'TG'),
	('Thailand', 'TH'),
	('Tajikistan', 'TJ'),
	('Tokelau', 'TK'),
	('Timor-Leste', 'TL'),
	('Turkmenistan', 'TM'),
	('Tunisia', 'TN'),
	('Tonga', 'TO'),
	('East Timor', 'TP'),
	('Turkey', 'TR'),
	('Trinidad and Tobago', 'TT'),
	('Tuvalu', 'TV'),
	('Taiwan', 'TW'),
	('Tanzania', 'TZ'),
	('Ukraine', 'UA'),
	('Uganda', 'UG'),
	('United Kingdom', 'UK'),
	('United States Minor Outlying Islands', 'UM'),
	('United Nations', 'UN'),
	('United States', 'US'),
	('Uruguay', 'UY'),
	('Uzbekistan', 'UZ'),
	('Holy See', 'VA'),
	('Saint Vincent and the Grenadines', 'VC'),
	('Venezuela', 'VE'),
	('Virgin Islands (British)', 'VG'),
	('Virgin Islands (U.S.)', 'VI'),
	('Viet Nam', 'VN'),
	('Vanuatu', 'VU'),
	('Wallis and Futuna', 'WF'),
	('Grenada', 'WG'),
	('Saint Lucia', 'WL'),
	('Samoa', 'WS'),
	('Saint Vincent', 'WV'),
	('Yemen', 'YE'),
	('Mayotte', 'YT'),
	('Yugoslavia', 'YU'),
	('Venezuela', 'YV'),
	('South Africa', 'ZA'),
	('Zambia', 'ZM'),
	('Zaire', 'ZR'),
	('Zimbabwe', 'ZW');

create table updates (
	id             integer        primary key autoincrement,
	subject        varchar        not null,
	body           varchar        not null,

	created_at     timestamp      not null                 check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),
	show_at        timestamp      not null                 check(show_at = strftime('%Y-%m-%d %H:%M:%S', show_at))
);
create index "updates#show_at" on updates(show_at);

create table exports (
	export_id         integer        primary key autoincrement,
	site_id           integer        not null,
	start_from_hit_id integer        not null,

	path              varchar        not null,
	created_at        timestamp      not null    check(created_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),

	finished_at       timestamp                  check(finished_at is null or finished_at = strftime('%Y-%m-%d %H:%M:%S', created_at)),
	last_hit_id       integer,
	num_rows          integer,
	size              varchar,
	hash              varchar,
	error             varchar,

	foreign key (site_id) references sites(id) on delete restrict on update restrict
);
create index "exports#site_id#created_at" on exports(site_id, created_at);

create table version (name varchar);
insert into version values
	('2019-10-16-1-geoip'),
	('2019-11-08-1-refs'),
	('2019-11-08-2-location_stats'),
	('2019-12-10-1-plans'),
	('2019-12-10-2-count_ref'),
	('2019-12-15-1-personal-free'),
	('2019-12-15-2-old'),
	('2019-12-17-1-business'),
	('2019-12-19-1-updates'),
	('2019-12-20-1-dailystat'),
	('2019-12-31-1-blank-days'),
	('2020-01-02-1-bot'),
	('2020-01-07-1-title-domain'),
	('2020-01-13-2-hit_stats_title'),
	('2020-01-18-1-sitename'),
	('2020-01-23-1-nformat'),
	('2020-01-24-1-rm-mobile'),
	('2020-01-24-2-domain'),
	('2020-01-27-2-rm-count-ref'),
	('2020-02-06-1-hitsid'),
	('2020-02-19-1-personalplus'),
	('2020-02-24-1-ref_stats'),
	('2020-03-03-1-flag'),
	('2020-03-16-1-size_stats'),
	('2020-03-16-2-rm-old'),
	('2020-03-27-1-isbot'),
	('2020-03-24-1-sessions'),
	('2020-04-06-1-event'),
	('2020-04-16-1-pwauth'),
	('2020-04-22-1-campaigns'),
	('2020-04-27-1-usage-flags'),
	('2020-04-28-1-fix'),
	('2020-05-13-1-unique-path'),
	('2020-05-17-1-rm-user-name'),
	('2020-05-16-1-os_stats'),
	('2020-05-18-1-domain-count'),
	('2020-05-21-1-ref-count'),
	('2020-05-23-1-event'),
	('2020-05-23-1-index'),
	('2020-05-23-2-drop-ref-stats'),
	('2020-06-03-1-cname-setup'),
	('2020-06-18-1-totp'),
	('2020-06-26-1-api-tokens'),
	('2020-06-26-1-record-export');
