PGDMP     -                    {            todoapp    13.1    13.1 M    $           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            %           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            &           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            '           1262    17118    todoapp    DATABASE     k   CREATE DATABASE todoapp WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'English_United States.1251';
    DROP DATABASE todoapp;
                postgres    false                        2615    17119    mappers    SCHEMA        CREATE SCHEMA mappers;
    DROP SCHEMA mappers;
                postgres    false                        2615    17120    todoapp    SCHEMA        CREATE SCHEMA todoapp;
    DROP SCHEMA todoapp;
                postgres    false                        2615    17121    utils    SCHEMA        CREATE SCHEMA utils;
    DROP SCHEMA utils;
                postgres    false            �           1247    17124    auth_register_dto    TYPE     �   CREATE TYPE todoapp.auth_register_dto AS (
	username character varying,
	email character varying,
	password character varying,
	role character varying
);
 %   DROP TYPE todoapp.auth_register_dto;
       todoapp          postgres    false    4            �            1255    17125    json_to_auth_register_dto(json)    FUNCTION     q  CREATE FUNCTION mappers.json_to_auth_register_dto(datajson json) RETURNS todoapp.auth_register_dto
    LANGUAGE plpgsql
    AS $$
declare
    dto todoapp.auth_register_dto;
begin
    dto.username := dataJson ->> 'username';
    dto.email := dataJson ->> 'email';
    dto.role := dataJson ->> 'role';
    dto.password := dataJson ->> 'password';
    return dto;
end
$$;
 @   DROP FUNCTION mappers.json_to_auth_register_dto(datajson json);
       mappers          postgres    false    7    652            �            1255    17126 0   auth_login(character varying, character varying)    FUNCTION     �  CREATE FUNCTION todoapp.auth_login(uname character varying DEFAULT NULL::character varying, pswd character varying DEFAULT NULL::character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
begin

    select * into t_user from todoapp.users t where t.username ilike uname and is_deleted  = 0;
    if not FOUND then
        raise exception using message = (format(get_text_document('/pdp/db_messages/usernotfound_', 'uz'), uname));
    end if;

    if utils.match_password(pswd, t_user.password) is false then
        raise exception 'Bad credentials';
    end if;
    return json_build_object('id', t_user.id,
                               'username', t_user.username,
                               'email', t_user.email,
                               'language', t_user.language,
                               'position', t_user.role,
                               'created_at', t_user.created_at,
                               'updated_at', t_user.updated_at)::text;

end
$$;
 S   DROP FUNCTION todoapp.auth_login(uname character varying, pswd character varying);
       todoapp          postgres    false    4            �            1255    17127    auth_register(text)    FUNCTION     �  CREATE FUNCTION todoapp.auth_register(dataparam text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newId    int4;
    dataJson json;
    --t_user   todoapp.users%rowtype;
    t_user   record;
    v_dto    todoapp.auth_register_dto;
begin
    if dataparam isnull or dataparam = '{}'::text then
        raise exception 'Data param can not be null';
    end if;

    dataJson := dataparam::json;
    v_dto := mappers.json_to_auth_register_dto(dataJson);
    /*select * into t_user from users t where t.username ilike v_dto.username;
    
    if (t_user is null) is false then
        raise exception 'Username % already taken',v_dto.username;
    end if;*/

/*    if exists(select * from users t where t.username ilike v_dto.username) then
        raise exception 'Username ''%'' already taken',v_dto.username;
    end if;*/

    if v_dto.username is null or trim(v_dto.username) = '' then
        raise exception 'Username is invalid';
    end if;

    if v_dto.email is null or trim(v_dto.email) = '' then
        raise exception 'Email is invalid';
    end if;


    if utils.check_email(v_dto.email) is false then
        raise exception 'Email is invalid';
    end if;

    select * into t_user from todoapp.users t where t.username ilike v_dto.username and is_deleted = 0;
    if FOUND then
        raise exception 'Username ''%'' already taken',t_user.username;
    end if;

    select * into t_user from todoapp.users t where t.email ilike v_dto.email and is_deleted = 0;
    if FOUND then
        raise exception 'Email ''%'' already taken',t_user.email;
    end if;

    if v_dto.password is null or trim(v_dto.password) = '' then
        raise exception 'Password is invalid';
    end if;

    insert into todoapp.users (username, password, email, role)
    values (v_dto.username,
            utils.encode_password(v_dto.password),
            v_dto.email,
            v_dto.role)
    returning id into newId;
    return newId;
end
$$;
 5   DROP FUNCTION todoapp.auth_register(dataparam text);
       todoapp          postgres    false    4            �            1255    17128 +   auth_user_update(character varying, bigint)    FUNCTION     �  CREATE FUNCTION todoapp.auth_user_update(dataparam character varying DEFAULT NULL::character varying, userid bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    dataJson   json;
    t_user     record;
    v_username varchar;
    v_email    varchar;
    v_role     varchar;
    v_language varchar;
    v_id       bigint;
begin

    call todoapp.isactive(userid);
    
    if dataparam is null or dataparam = '{}'::text then
        raise exception 'Dataparam can not be null';
    end if;

    dataJson := dataparam::json;

    v_id := dataJson ->> 'id';
    v_username := dataJson ->> 'username';
    v_email := dataJson ->> 'email';
    v_language := dataJson ->> 'language';
    v_role := dataJson ->> 'role';

    if v_id != userid and todoapp.hasRole(userid, 'ADMIN') is false then
        raise exception 'Permission denied';
    end if;
    -- TODO check username, password, email, role

    if utils.check_email(v_email) is false then
        raise exception 'Email invalid ''%''', v_email;
    end if;

    select * into t_user from todoapp.users t where t.is_deleted = 0 and t.id = v_id;
    if not FOUND then
        raise exception 'User not found by id ''%''',v_id;
    end if;

    if v_username is null then
        v_username := t_user.username;
    end if;
    if v_email is null then
        v_email := t_user.email;
    end if;
    if v_role is null then
        v_role := t_user.role;
    end if;
    if v_language is null then
        v_language := t_user.language;
    end if;

    update todoapp.users
    set username = v_username,
        role     = v_role,
        language = v_language,
        email    = v_email
    where id = v_id;

    return true;
end
$$;
 T   DROP FUNCTION todoapp.auth_user_update(dataparam character varying, userid bigint);
       todoapp          postgres    false    4            �            1255    17300 7   get_text_document(character varying, character varying)    FUNCTION     l  CREATE FUNCTION todoapp.get_text_document(p_filename character varying, language character varying) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    AS $$
    -- Set the end read to some big number because we are too lazy to grab the length
  -- and it will cut of at the EOF anyway
  SELECT CAST(pg_read_file(concat(p_filename, language, '.txt')) AS TEXT);
$$;
 c   DROP FUNCTION todoapp.get_text_document(p_filename character varying, language character varying);
       todoapp          postgres    false    4            �            1255    17129 "   hasrole(bigint, character varying)    FUNCTION     �  CREATE FUNCTION todoapp.hasrole(userid bigint DEFAULT NULL::bigint, role character varying DEFAULT NULL::character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
BEGIN
    if userid is null or role is null then
        return false;
    end if;
    select * into t_user from users t where t.is_deleted = 0 and t.id = userid;
    return FOUND and t_user.role = role;
END
$$;
 F   DROP FUNCTION todoapp.hasrole(userid bigint, role character varying);
       todoapp          postgres    false    4            �            1255    17130    isactive(bigint) 	   PROCEDURE     �  CREATE PROCEDURE todoapp.isactive(userid bigint DEFAULT NULL::bigint)
    LANGUAGE plpgsql
    AS $$
declare
    t_user record;
BEGIN
    if userid is null then
        raise exception 'User id is null';
    end if;

    select * into t_user from users t where t.is_deleted = 0 and t.id = userid;
    if not FOUND then
        raise exception 'User not found by id : ''%''',userid;
    end if;
END
$$;
 0   DROP PROCEDURE todoapp.isactive(userid bigint);
       todoapp          postgres    false    4            �            1255    17301    project_column_details(record)    FUNCTION     &  CREATE FUNCTION todoapp.project_column_details(pc record DEFAULT NULL::record) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare

begin
    if pc is null then
        return null;
    else
        return row_to_json(X)::jsonb FROM (SELECT pc.id, pc.name, pc.order) AS X;
    end if;
end
$$;
 9   DROP FUNCTION todoapp.project_column_details(pc record);
       todoapp          postgres    false    4            �            1255    17131    project_create(text, bigint)    FUNCTION     6  CREATE FUNCTION todoapp.project_create(dataparam text DEFAULT NULL::text, userid bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$

declare
    dataJson json;
    newId    bigint;

begin
    call todoapp.isactive(userid);

    if dataparam is null or dataparam = '{}'::text then
        raise exception 'Datapram invalid';
    end if;

    dataJson := cast(dataparam as json);

    if exists(select * from todoapp.project t where not is_deleted and t.code = upper(dataJson ->> 'code')) then
        raise exception 'Project with code ''%'' already exists', dataJson ->> 'code';
    end if;

    insert into todoapp.project(title, code, description, created_by)
    values (dataJson ->> 'title',
            upper(dataJson ->> 'code'),
            dataJson ->> 'description',
            userid)
    returning id into newId;

    insert into todoapp.project_column (name, "order", project_id, created_by)
    values ('TODO', nextval('todoapp.project_column_order_seq'), newId, userid),
           ('DOING', nextval('todoapp.project_column_order_seq'), newId, userid),
           ('DONE', nextval('todoapp.project_column_order_seq'), newId, userid);
    
    insert into todoapp.project_member (user_id, project_id, is_lead, created_by)
    values (userid, newId, true, userid);
    
    return newId;
end;
$$;
 E   DROP FUNCTION todoapp.project_create(dataparam text, userid bigint);
       todoapp          postgres    false    4            �            1255    17132    project_details(bigint, bigint)    FUNCTION     �  CREATE FUNCTION todoapp.project_details(projectid bigint DEFAULT NULL::bigint, userid bigint DEFAULT NULL::bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    result             json;
    userJsonb          jsonb;
    projectMemberJsonb jsonb;
    r_user             record;
    r_project          record;
    r_project_member   record;
    r_project_column   record;
    projectColumnJsonb jsonb;
    p_column           jsonb;
begin
    CALL todoapp.isactive(userid);
    select * into r_project from todoapp.project t where not t.is_deleted and t.id = projectid;

    if not FOUND then
        raise exception 'Project not found by id ''%'' ', projectid;
    end if;

    for r_project_column in select * from todoapp.project_column t where not t.is_deleted and t.project_id = projectid
        loop
            p_column := jsonb_build_object('id', r_project_column.id);
            p_column := p_column || jsonb_build_object('name', r_project_column.name);
            p_column := p_column || jsonb_build_object('order', r_project_column.order);
            p_column := p_column || jsonb_build_object('project_id', r_project_column.project_id);
            p_column := p_column || jsonb_build_object('created_by', r_project_column.created_by);
            p_column := p_column || jsonb_build_object('created_at', r_project_column.created_at);
            p_column := p_column || jsonb_build_object('updated_at', r_project_column.updated_at);
            p_column := p_column || jsonb_build_object('updated_by', r_project_column.updated_by);
            if projectColumnJsonb is null then
                projectColumnJsonb := '[]' || p_column;
            else
                projectColumnJsonb:=projectColumnJsonb||p_column;
            end if;
        end loop;

    for r_project_member in select * from todoapp.project_member t where not t.is_deleted and t.project_id = projectid
        loop

            select * into r_user from todoapp.users t where t.is_deleted = 0 and t.id = r_project_member.user_id;
            if FOUND then
                userJsonb := jsonb_build_object('id', r_user.id);
                userJsonb := userJsonb || jsonb_build_object('username', r_user.username);
                userJsonb := userJsonb || jsonb_build_object('email', r_user.email);
                userJsonb := userJsonb || jsonb_build_object('language', r_user.language);
                userJsonb := userJsonb || jsonb_build_object('role', r_user.role);
                if projectMemberJsonb is null then
                    projectMemberJsonb := '[]' || userJsonb;
                else
                    projectMemberJsonb := projectMemberJsonb || userJsonb;
                end if;
            end if;
        end loop;

    result := json_build_object(
            'id', r_project.id,
            'title', r_project.title,
            'code', r_project.code,
            'description', r_project.description,
            'completed', r_project.completed,
            'created_at', r_project.created_at,
            'created_by', r_project.created_by,
--             'columns', columns,
            'members', projectMemberJsonb::json,
            'columns', projectColumnJsonb
        );
    return result::text;
end
$$;
 H   DROP FUNCTION todoapp.project_details(projectid bigint, userid bigint);
       todoapp          postgres    false    4            �            1255    17302    userinfo(bigint)    FUNCTION     �  CREATE FUNCTION todoapp.userinfo(userid bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
    r_user record;
begin
    select * into r_user from todoapp.users u where u.is_deleted = 0 and u.id = userid;
    if FOUND then
        return row_to_json(X)::jsonb
            FROM (SELECT r_user.id, r_user.username, r_user.email, r_user.language, r_user.role) AS X;
    else
        return null;
    end if;
end
$$;
 /   DROP FUNCTION todoapp.userinfo(userid bigint);
       todoapp          postgres    false    4            �            1255    17133    check_email(character varying)    FUNCTION       CREATE FUNCTION utils.check_email(email character varying DEFAULT NULL::character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare
    pattern varchar := '^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-]+)(\.[a-zA-Z]{2,5}){1,2}$';
BEGIN
    return email ~* pattern;
END
$_$;
 :   DROP FUNCTION utils.check_email(email character varying);
       utils          postgres    false    6            �            1255    17134 "   encode_password(character varying)    FUNCTION     '  CREATE FUNCTION utils.encode_password(rawpassword character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
begin
    if rawPassword is null then
        raise exception 'Invalid Password null';
    end if;
    return utils.crypt(rawPassword, utils.gen_salt('bf', 4));
end
$$;
 D   DROP FUNCTION utils.encode_password(rawpassword character varying);
       utils          postgres    false    6            �            1255    17135 4   match_password(character varying, character varying)    FUNCTION     �  CREATE FUNCTION utils.match_password(rawpassword character varying, encodedpassword character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare

begin
    if rawPassword is null then
        raise exception 'Invalid Password null';
    end if;

    if encodedPassword is null then
        raise exception 'Invalid encoded Password null';
    end if;
    return encodedPassword = utils.crypt(rawPassword, encodedPassword);
end
$$;
 f   DROP FUNCTION utils.match_password(rawpassword character varying, encodedpassword character varying);
       utils          postgres    false    6            �            1259    17136    project    TABLE     �  CREATE TABLE todoapp.project (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description character varying NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint,
    updated_at timestamp with time zone,
    code character varying NOT NULL
);
    DROP TABLE todoapp.project;
       todoapp         heap    postgres    false    4            �            1259    17145    project_column    TABLE     v  CREATE TABLE todoapp.project_column (
    id bigint NOT NULL,
    name character varying NOT NULL,
    "order" smallint NOT NULL,
    project_id bigint NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint,
    updated_at timestamp with time zone
);
 #   DROP TABLE todoapp.project_column;
       todoapp         heap    postgres    false    4            �            1259    17153    project_column_id_seq    SEQUENCE        CREATE SEQUENCE todoapp.project_column_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE todoapp.project_column_id_seq;
       todoapp          postgres    false    205    4            (           0    0    project_column_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE todoapp.project_column_id_seq OWNED BY todoapp.project_column.id;
          todoapp          postgres    false    206            �            1259    17155    project_column_order_seq    SEQUENCE     �   CREATE SEQUENCE todoapp.project_column_order_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE todoapp.project_column_order_seq;
       todoapp          postgres    false    4            �            1259    17157    project_id_seq    SEQUENCE     x   CREATE SEQUENCE todoapp.project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE todoapp.project_id_seq;
       todoapp          postgres    false    204    4            )           0    0    project_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE todoapp.project_id_seq OWNED BY todoapp.project.id;
          todoapp          postgres    false    208            �            1259    17159    project_member    TABLE     i  CREATE TABLE todoapp.project_member (
    id bigint NOT NULL,
    user_id bigint,
    project_id bigint,
    is_lead boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint,
    updated_at timestamp with time zone
);
 #   DROP TABLE todoapp.project_member;
       todoapp         heap    postgres    false    4            �            1259    17165    project_member_id_seq    SEQUENCE        CREATE SEQUENCE todoapp.project_member_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE todoapp.project_member_id_seq;
       todoapp          postgres    false    209    4            *           0    0    project_member_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE todoapp.project_member_id_seq OWNED BY todoapp.project_member.id;
          todoapp          postgres    false    210            �            1259    17167    task_comment    TABLE     �  CREATE TABLE todoapp.task_comment (
    id bigint NOT NULL,
    task_id bigint,
    message character varying NOT NULL,
    comment_type character varying DEFAULT 'MESSAGE'::character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint,
    updated_at timestamp with time zone
);
 !   DROP TABLE todoapp.task_comment;
       todoapp         heap    postgres    false    4            �            1259    17176    task_member    TABLE     e   CREATE TABLE todoapp.task_member (
    id bigint NOT NULL,
    task_id bigint,
    user_id bigint
);
     DROP TABLE todoapp.task_member;
       todoapp         heap    postgres    false    4            �            1259    17179    tasks    TABLE     !  CREATE TABLE todoapp.tasks (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description character varying,
    project_column_id bigint,
    priority character varying DEFAULT 'LOW'::character varying NOT NULL,
    level character varying DEFAULT 'EASY'::character varying NOT NULL,
    "order" smallint NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint,
    updated_at timestamp with time zone
);
    DROP TABLE todoapp.tasks;
       todoapp         heap    postgres    false    4            �            1259    17189    users    TABLE     �  CREATE TABLE todoapp.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(100) NOT NULL,
    email character varying(50) NOT NULL,
    role character varying(50) DEFAULT 'USER'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone,
    language character varying DEFAULT 'RU'::character varying NOT NULL,
    is_deleted smallint DEFAULT 0 NOT NULL
);
    DROP TABLE todoapp.users;
       todoapp         heap    postgres    false    4            �            1259    17199    users_id_seq    SEQUENCE     �   CREATE SEQUENCE todoapp.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE todoapp.users_id_seq;
       todoapp          postgres    false    4    214            +           0    0    users_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE todoapp.users_id_seq OWNED BY todoapp.users.id;
          todoapp          postgres    false    215            _           2604    17303 
   project id    DEFAULT     j   ALTER TABLE ONLY todoapp.project ALTER COLUMN id SET DEFAULT nextval('todoapp.project_id_seq'::regclass);
 :   ALTER TABLE todoapp.project ALTER COLUMN id DROP DEFAULT;
       todoapp          postgres    false    208    204            b           2604    17304    project_column id    DEFAULT     x   ALTER TABLE ONLY todoapp.project_column ALTER COLUMN id SET DEFAULT nextval('todoapp.project_column_id_seq'::regclass);
 A   ALTER TABLE todoapp.project_column ALTER COLUMN id DROP DEFAULT;
       todoapp          postgres    false    206    205            f           2604    17305    project_member id    DEFAULT     x   ALTER TABLE ONLY todoapp.project_member ALTER COLUMN id SET DEFAULT nextval('todoapp.project_member_id_seq'::regclass);
 A   ALTER TABLE todoapp.project_member ALTER COLUMN id DROP DEFAULT;
       todoapp          postgres    false    210    209            r           2604    17306    users id    DEFAULT     f   ALTER TABLE ONLY todoapp.users ALTER COLUMN id SET DEFAULT nextval('todoapp.users_id_seq'::regclass);
 8   ALTER TABLE todoapp.users ALTER COLUMN id DROP DEFAULT;
       todoapp          postgres    false    215    214                      0    17136    project 
   TABLE DATA           �   COPY todoapp.project (id, title, description, completed, is_deleted, created_by, created_at, updated_by, updated_at, code) FROM stdin;
    todoapp          postgres    false    204   ��                 0    17145    project_column 
   TABLE DATA           �   COPY todoapp.project_column (id, name, "order", project_id, is_deleted, created_by, created_at, updated_by, updated_at) FROM stdin;
    todoapp          postgres    false    205   ��                 0    17159    project_member 
   TABLE DATA           �   COPY todoapp.project_member (id, user_id, project_id, is_lead, is_deleted, created_by, created_at, updated_by, updated_at) FROM stdin;
    todoapp          postgres    false    209   b�                 0    17167    task_comment 
   TABLE DATA           �   COPY todoapp.task_comment (id, task_id, message, comment_type, is_deleted, created_by, created_at, updated_by, updated_at) FROM stdin;
    todoapp          postgres    false    211   ��                 0    17176    task_member 
   TABLE DATA           <   COPY todoapp.task_member (id, task_id, user_id) FROM stdin;
    todoapp          postgres    false    212   Ӑ                 0    17179    tasks 
   TABLE DATA           �   COPY todoapp.tasks (id, title, description, project_column_id, priority, level, "order", is_deleted, created_by, created_at, updated_by, updated_at) FROM stdin;
    todoapp          postgres    false    213   �                  0    17189    users 
   TABLE DATA           s   COPY todoapp.users (id, username, password, email, role, created_at, updated_at, language, is_deleted) FROM stdin;
    todoapp          postgres    false    214   �       ,           0    0    project_column_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('todoapp.project_column_id_seq', 15, true);
          todoapp          postgres    false    206            -           0    0    project_column_order_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('todoapp.project_column_order_seq', 16, true);
          todoapp          postgres    false    207            .           0    0    project_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('todoapp.project_id_seq', 10, true);
          todoapp          postgres    false    208            /           0    0    project_member_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('todoapp.project_member_id_seq', 2, true);
          todoapp          postgres    false    210            0           0    0    users_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('todoapp.users_id_seq', 10, true);
          todoapp          postgres    false    215            t           2606    17206    project project_code_key 
   CONSTRAINT     T   ALTER TABLE ONLY todoapp.project
    ADD CONSTRAINT project_code_key UNIQUE (code);
 C   ALTER TABLE ONLY todoapp.project DROP CONSTRAINT project_code_key;
       todoapp            postgres    false    204            x           2606    17208 "   project_column project_column_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY todoapp.project_column
    ADD CONSTRAINT project_column_pkey PRIMARY KEY (id);
 M   ALTER TABLE ONLY todoapp.project_column DROP CONSTRAINT project_column_pkey;
       todoapp            postgres    false    205            z           2606    17210 "   project_member project_member_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY todoapp.project_member
    ADD CONSTRAINT project_member_pkey PRIMARY KEY (id);
 M   ALTER TABLE ONLY todoapp.project_member DROP CONSTRAINT project_member_pkey;
       todoapp            postgres    false    209            v           2606    17212    project project_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY todoapp.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);
 ?   ALTER TABLE ONLY todoapp.project DROP CONSTRAINT project_pkey;
       todoapp            postgres    false    204            |           2606    17214    task_comment task_comment_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY todoapp.task_comment
    ADD CONSTRAINT task_comment_pkey PRIMARY KEY (id);
 I   ALTER TABLE ONLY todoapp.task_comment DROP CONSTRAINT task_comment_pkey;
       todoapp            postgres    false    211            ~           2606    17216    task_member task_member_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY todoapp.task_member
    ADD CONSTRAINT task_member_pkey PRIMARY KEY (id);
 G   ALTER TABLE ONLY todoapp.task_member DROP CONSTRAINT task_member_pkey;
       todoapp            postgres    false    212            �           2606    17218    tasks tasks_pkey 
   CONSTRAINT     O   ALTER TABLE ONLY todoapp.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
 ;   ALTER TABLE ONLY todoapp.tasks DROP CONSTRAINT tasks_pkey;
       todoapp            postgres    false    213            �           2606    17220    users users_email_key 
   CONSTRAINT     R   ALTER TABLE ONLY todoapp.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
 @   ALTER TABLE ONLY todoapp.users DROP CONSTRAINT users_email_key;
       todoapp            postgres    false    214            �           2606    17222    users users_pkey 
   CONSTRAINT     O   ALTER TABLE ONLY todoapp.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 ;   ALTER TABLE ONLY todoapp.users DROP CONSTRAINT users_pkey;
       todoapp            postgres    false    214            �           2606    17224    users users_username_key 
   CONSTRAINT     X   ALTER TABLE ONLY todoapp.users
    ADD CONSTRAINT users_username_key UNIQUE (username);
 C   ALTER TABLE ONLY todoapp.users DROP CONSTRAINT users_username_key;
       todoapp            postgres    false    214            �           2606    17225 -   project_column project_column_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project_column
    ADD CONSTRAINT project_column_created_by_fkey FOREIGN KEY (created_by) REFERENCES todoapp.users(id);
 X   ALTER TABLE ONLY todoapp.project_column DROP CONSTRAINT project_column_created_by_fkey;
       todoapp          postgres    false    2948    214    205            �           2606    17230 -   project_column project_column_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project_column
    ADD CONSTRAINT project_column_project_id_fkey FOREIGN KEY (project_id) REFERENCES todoapp.project(id);
 X   ALTER TABLE ONLY todoapp.project_column DROP CONSTRAINT project_column_project_id_fkey;
       todoapp          postgres    false    204    205    2934            �           2606    17235    project project_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project
    ADD CONSTRAINT project_created_by_fkey FOREIGN KEY (created_by) REFERENCES todoapp.users(id);
 J   ALTER TABLE ONLY todoapp.project DROP CONSTRAINT project_created_by_fkey;
       todoapp          postgres    false    2948    214    204            �           2606    17240 -   project_member project_member_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project_member
    ADD CONSTRAINT project_member_created_by_fkey FOREIGN KEY (created_by) REFERENCES todoapp.users(id);
 X   ALTER TABLE ONLY todoapp.project_member DROP CONSTRAINT project_member_created_by_fkey;
       todoapp          postgres    false    2948    209    214            �           2606    17245 -   project_member project_member_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project_member
    ADD CONSTRAINT project_member_project_id_fkey FOREIGN KEY (project_id) REFERENCES todoapp.project(id);
 X   ALTER TABLE ONLY todoapp.project_member DROP CONSTRAINT project_member_project_id_fkey;
       todoapp          postgres    false    2934    209    204            �           2606    17250 *   project_member project_member_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.project_member
    ADD CONSTRAINT project_member_user_id_fkey FOREIGN KEY (user_id) REFERENCES todoapp.users(id);
 U   ALTER TABLE ONLY todoapp.project_member DROP CONSTRAINT project_member_user_id_fkey;
       todoapp          postgres    false    209    2948    214            �           2606    17255    project project_updated_by    FK CONSTRAINT     ~   ALTER TABLE ONLY todoapp.project
    ADD CONSTRAINT project_updated_by FOREIGN KEY (updated_by) REFERENCES todoapp.users(id);
 E   ALTER TABLE ONLY todoapp.project DROP CONSTRAINT project_updated_by;
       todoapp          postgres    false    214    2948    204            �           2606    17260 )   task_comment task_comment_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.task_comment
    ADD CONSTRAINT task_comment_created_by_fkey FOREIGN KEY (created_by) REFERENCES todoapp.users(id);
 T   ALTER TABLE ONLY todoapp.task_comment DROP CONSTRAINT task_comment_created_by_fkey;
       todoapp          postgres    false    214    211    2948            �           2606    17265 &   task_comment task_comment_task_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.task_comment
    ADD CONSTRAINT task_comment_task_id_fkey FOREIGN KEY (task_id) REFERENCES todoapp.tasks(id);
 Q   ALTER TABLE ONLY todoapp.task_comment DROP CONSTRAINT task_comment_task_id_fkey;
       todoapp          postgres    false    211    213    2944            �           2606    17270 $   task_member task_member_task_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.task_member
    ADD CONSTRAINT task_member_task_id_fkey FOREIGN KEY (task_id) REFERENCES todoapp.tasks(id);
 O   ALTER TABLE ONLY todoapp.task_member DROP CONSTRAINT task_member_task_id_fkey;
       todoapp          postgres    false    212    213    2944            �           2606    17275 $   task_member task_member_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.task_member
    ADD CONSTRAINT task_member_user_id_fkey FOREIGN KEY (user_id) REFERENCES todoapp.users(id);
 O   ALTER TABLE ONLY todoapp.task_member DROP CONSTRAINT task_member_user_id_fkey;
       todoapp          postgres    false    214    2948    212            �           2606    17280    tasks tasks_created_by_fkey    FK CONSTRAINT        ALTER TABLE ONLY todoapp.tasks
    ADD CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES todoapp.users(id);
 F   ALTER TABLE ONLY todoapp.tasks DROP CONSTRAINT tasks_created_by_fkey;
       todoapp          postgres    false    2948    214    213            �           2606    17285 "   tasks tasks_project_column_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todoapp.tasks
    ADD CONSTRAINT tasks_project_column_id_fkey FOREIGN KEY (project_column_id) REFERENCES todoapp.project_column(id);
 M   ALTER TABLE ONLY todoapp.tasks DROP CONSTRAINT tasks_project_column_id_fkey;
       todoapp          postgres    false    205    2936    213               V   x�34�t�U02�(��JM.QH�/RH+�S����LBKN##c]C]cCs+c+C=3KSmS�?�od����� Hz�         U   x���1� D�z���,Fj���ƒ��A�@�������*>��S:����$�|j�]��dε?�mE�T��^D~ �         D   x�3��44�,�L2���uu�ͭ��L��,LL�L9c��������h@������ �x            x������ � �            x������ � �            x������ � �          �   x�E��N�@ ���]�3��;0�JBI�
�6� "B���{5���HR�����-�ս��͸�����>K�Ԇ?'lˮ�&V���TA�F��FmO���aK0�D�d��1��R�;�䐐lO@C ����ׇ������@��b;��:��D���u�������o��r�#�>�5q��(��H�A�
���w�}��i���C�     