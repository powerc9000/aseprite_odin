package aseprite;

import "core:os";
import "core:mem";
import "core:fmt";
import "core:strings"
import "core:c";
import raylib "../raylib_odin/raylib_defs";

foreign import miniz "../clibs/miniz.o";

foreign miniz {
	tinfl_decompress_mem_to_heap :: proc(rawptr, c.size_t, ^c.size_t, c.int) -> rawptr ---;
	mz_free :: proc(rawptr) ---;
}

ASE_BYTE :: u8;
ASE_WORD :: u16le;
ASE_SHORT :: i16le;
ASE_DWORD :: u32le;
ASE_LONG :: i32le;

ASE_FIXED :: struct #packed{
	hi: ASE_WORD,
	lo: ASE_WORD
};

ASE_STRING :: struct #packed {
	len: ASE_WORD,
	chars: []ASE_BYTE
};

ASE_PIXEL_RGBA :: struct #packed { 
	r: ASE_BYTE,
	g: ASE_BYTE,
	b: ASE_BYTE,
	a: ASE_BYTE
};

ASE_PIXEL_GRAYSCALE :: struct #packed {
	value: ASE_BYTE,
	alpha: ASE_BYTE
};

ASE_PIXEL_INDEXED :: distinct ASE_BYTE;

ASE_HEADER :: struct #packed {
	fileSize: ASE_DWORD,
	magicNumber: ASE_WORD,
	frames: ASE_WORD,
	width: ASE_WORD,
	height: ASE_WORD,
	depth: ASE_WORD,
	flags: ASE_DWORD,
	speed: ASE_WORD,
	pad: ASE_DWORD,
	pad2: ASE_DWORD,
	transparentColorIndex: ASE_BYTE,
	ignored: [3]ASE_BYTE,
	colors: ASE_WORD,
	pixelWidth: ASE_BYTE,
	pixelHeight: ASE_BYTE,
	gridX: ASE_SHORT,
	gridY: ASE_SHORT,
	gridWidth: ASE_WORD,
	gridHeight: ASE_WORD,
	reserved: [84]ASE_BYTE
};

ASE_FRAME_HEADER :: struct #packed {
	totalBytes : ASE_DWORD,
	magicNumber: ASE_WORD,
	_totalChunks: ASE_WORD,
	frameDuration: ASE_WORD,
	reserved: [2]ASE_BYTE,
	totalChunks: ASE_DWORD
};


ASE_CHUNK_HEADER :: struct #packed {
	size: ASE_DWORD,
	type: ASE_WORD
};

ASE_FRAME_HEADER_MAGIC : ASE_WORD : 0xF1FA;
ASE_HEADER_MAGIC : ASE_WORD : 0xA5E0;

ASE_CHUNK_TYPES :: enum ASE_WORD {
	OLD_PALETTE = 0x0004,
	OLD_PALETTE_2 = 0x0011,
	LAYER = 0x2004,
	CEL = 0x2005,
	CEL_EXTRA = 0x2006,
	COLOR_PROFILE = 0x2007,
	MASK = 0x2016, //deprecated
	PATH = 0x2017, //never used
	TAGS = 0x2018,
	PALETTE = 0x2019,
	USER_DATA = 0x2020,
	SLICE = 0x2022
};

ASE_BLEND_MDOE :: enum ASE_WORD {
	Normal         = 0,
	Multiply       = 1,
	Screen         = 2,
	Overlay        = 3,
	Darken         = 4,
	Lighten        = 5,
	Color_Dodge    = 6,
	Color_Burn     = 7,
	Hard_Light     = 8,
	Soft_Light     = 9,
	Difference     = 10,
	Exclusion      = 11,
	Hue            = 12,
	Saturation     = 13,
	Color          = 14,
	Luminosity     = 15,
	Addition       = 16,
	Subtract       = 17,
	Divide         = 18
};


ASE_LAYER_CHUNK :: struct #packed {
	flags: ASE_WORD,
	type: ASE_WORD,
	childLevel: ASE_WORD,
	width: ASE_WORD, // ignored
	height: ASE_WORD, // ignored
	blendMode: ASE_WORD,
	opacity: ASE_BYTE,
	reserved: [3]ASE_BYTE,
	nameLen: ASE_WORD
};

ASE_LAYER_CHUNK_NAME :: ASE_STRING;

ASE_LAYER_CHUNK_TYPE :: enum ASE_WORD {
	Normal,
	Group
}
ASE_LAYER_CHUNK_FLAGS_INFO :: enum ASE_WORD {
	Visible,
	Editable,
	Locked,
	Background,
	PreferLinkedCels, 
	Collapsed,
	ReferenceLayer
}
ASE_LAYER_CHUNK_FLAGS :: bit_set[ASE_LAYER_CHUNK_FLAGS_INFO; ASE_WORD];

CEL_CHUNK_HEADER :: struct #packed {
	index: ASE_WORD,
	x: ASE_SHORT,
	y: ASE_SHORT,
	opacity: ASE_BYTE,
	type: ASE_WORD,
	reserved: [7]byte
};

CEL_CHUNK_RAW_CEL :: struct #packed {
	width: ASE_WORD,
	height: ASE_WORD
	//Also has Pixel array but that will vary based on color depth
};

CEL_CHUNK_LINKED_CEL :: distinct ASE_WORD;

CEL_CHUNK_COMPRESSED_IMAGE :: struct #packed {
	width: ASE_WORD,
	height: ASE_WORD,
	data: []ASE_BYTE // zlib compressed
};

CEL_EXTRA_CHUNK :: struct #packed {
	flags: ASE_DWORD,
	x: ASE_FIXED,
	y: ASE_FIXED,
	width: ASE_FIXED,
	height: ASE_FIXED,
	reserved: [16]ASE_BYTE
};

COLOR_PROFILE_TYPE :: enum ASE_WORD {
	None = 0,
	SRGB = 1,
	Embedded = 2
}

COLOR_PROFILE_CHUNK :: struct #packed {
	type: COLOR_PROFILE_TYPE,
	flags: ASE_WORD,
	fixedGamma: ASE_FIXED,
	reserved: [8]byte
	// Will have ICC color profile if type is icc
};

MASK_CHUNK :: struct #packed {
	x: ASE_SHORT,
	y: ASE_SHORT,
	width: ASE_WORD,
	height: ASE_WORD,
	reserved: [8]byte,
	name: ASE_STRING,
	bitMapData: []ASE_BYTE //(size = height * ((width+7)/8))
};

TAGS_CHUNK_HEADER :: struct #packed {
	tagCount: ASE_WORD,
	reserved: [8]ASE_BYTE
};

ASE_ANIMTION_DIRECTION :: enum ASE_BYTE {
	Forward = 0,
	Reverse = 1,
	PingPong = 2
}

TAGS_CHUNK_DATA :: struct #packed {
	fromFrame: ASE_WORD,
	toFrame: ASE_WORD,
	direction: ASE_ANIMTION_DIRECTION,
	reserved: [8]ASE_BYTE,
	tagColor: [3]ASE_BYTE, //who cares
	pad: ASE_BYTE,
	name: ASE_STRING
}

PALETTE_CHUNK_HEADER :: struct #packed {
	size: ASE_DWORD,
	firstIndex: ASE_DWORD,
	lastIndex: ASE_DWORD,
	reserved: [8]ASE_BYTE
};

PALLET_CHUNK_DATA :: struct #packed {
	flags: ASE_WORD,
	red: ASE_BYTE,
	green: ASE_BYTE,
	blue: ASE_BYTE,
	alpha: ASE_BYTE,
};

USER_DATA_CHUNK :: struct #packed {
	flags: ASE_DWORD
};

USER_DATA_CHUNK_FLAGS_BIT_1 :: ASE_STRING;
USER_DATA_CHUNK_FLAGS_BIT_2 :: struct #packed {
	red: ASE_BYTE,
	green: ASE_BYTE,
	blue: ASE_BYTE,
	alpha: ASE_BYTE
}

SLICE_CHUNK_HEADER :: struct #packed {
	total: ASE_DWORD,
	flags: ASE_DWORD,
	reserved: ASE_DWORD,
	name: ASE_STRING
};

SLICE_CHUNK_DATA :: struct #packed {
	frameNumber: ASE_DWORD,
	x: ASE_LONG,
	y: ASE_LONG,
	width: ASE_DWORD,
	height: ASE_DWORD
}

SLICE_CHUNK_DATA_BIT_1 :: struct #packed {
	centerX: ASE_LONG,
	centerY: ASE_LONG,
	centerWidth: ASE_DWORD,
	centerHeight: ASE_DWORD
};

SLICE_CHUNK_DATA_BIT_2 :: struct #packed {
	pivotX: ASE_LONG,
	pivotY: ASE_LONG
}

Ase_Layer :: struct {
	index: int,
	name: string,
	groupPath: []string
}

Ase_Cel :: struct {
	layerIndex: int,
	x: int,
	y: int,
	opacity: f32,
	data: []u8
}

Ase_Frame :: struct {
	duration: int,
	cels: [dynamic]Ase_Cel,
	tags: []int
}

Ase_Tag :: struct {
	name: string,
	fromFrame: int,
	toFrame: int
}

Ase_Document :: struct {
	width: int,
	height: int,
	header: ASE_HEADER,
	layers: [dynamic]Ase_Layer,
	frames: [dynamic]Ase_Frame,
	tags: [dynamic]Ase_Tag
}

read_file :: proc(path: string) {
	data,_ := os.read_entire_file(path);
	document : Ase_Document;
	current := 0;
	header := ASE_HEADER{};
	frame := ASE_FRAME_HEADER{};
	read_from_buffer(mem.ptr_to_bytes(&header), data, &current);
	document.width = int(header.width);
	document.height = int(header.height);
	fmt.println(header);
	for frameIndex in 0..<header.frames {
		old := current;
		read_from_buffer(mem.ptr_to_bytes(&frame), data, &current);
		fmt.println(frame);
		for _ in 0..<frame.totalChunks {
			chunkStart := current;
			chunk := ASE_CHUNK_HEADER{};
			read_from_buffer(mem.ptr_to_bytes(&chunk), data, &current);
			type := ASE_CHUNK_TYPES(chunk.type);
			fmt.println(chunk);
			layerIndex := 0;
			#partial switch type {
				case .LAYER: {
					layerData := ASE_LAYER_CHUNK{};
					read_from_buffer(mem.ptr_to_bytes(&layerData), data, &current);
					layerName := make([]ASE_BYTE, layerData.nameLen);
					read_from_buffer(layerName, data, &current);
					fmt.println("Layer Chunk", int(layerData.nameLen));
					name := strings.clone(strings.string_from_ptr(&layerName[0], int(layerData.nameLen)));
					fmt.println(transmute(ASE_LAYER_CHUNK_FLAGS)layerData.flags, layerData.flags, ASE_LAYER_CHUNK_TYPE(layerData.type));

					layer : Ase_Layer = {
						index=layerIndex,
						name=name,
					};

					append(&document.layers, layer);

					layerIndex += 1;

				}
				case .CEL:{
					celHeader := CEL_CHUNK_HEADER{};
					read_from_buffer(mem.ptr_to_bytes(&celHeader), data, &current);
					x := f32(celHeader.x);
					y := f32(celHeader.y);
					fmt.println("CEL HEADER");
					fmt.println(celHeader);
					if celHeader.type == 2 {
						width := read_type(ASE_WORD, data, &current);
						height := read_type(ASE_WORD, data, &current);
						fmt.println("w, h", width, height);
						leftOver := int(chunk.size - size_of(chunk) - size_of(celHeader) - size_of(width) * 2);
						fmt.println(chunk.size, leftOver);
						source := data[current:current + leftOver];
						cellData := raylib.decode_zlib(source);
						fmt.println("total size", len(cellData));
						fmt.println("calling raylib");
						parentImage := raylib.GenImageColor(cast(c.int)document.width, cast(c.int)document.height, raylib.COLOR_TRANSPARENT);
						image := raylib.LoadImagePro(&cellData[0], c.int(width), c.int(height), raylib.PixelFormat.UNCOMPRESSED_R8G8B8A8);
						src: raylib.Rectangle = {{0,0}, f32(width), f32(height)};
						dest: raylib.Rectangle = {{x, y}, f32(width), f32(height)};
						raylib.ImageDraw(&parentImage, image, src, dest, raylib.COLOR_WHITE);
						raylib.UnloadImage(parentImage);
						raylib.UnloadImage(image);
						parentLayer := document.layers[int(celHeader.index)];
						raylib.export_image(parentImage, fmt.tprintf("build/{1}{0}.png", parentLayer.name, frameIndex));
						fmt.println("bytes in data", leftOver);
					}
				}
				case .COLOR_PROFILE: {
					fmt.println("COLOR PROFILE");
					profile := COLOR_PROFILE_CHUNK{};
					fmt.println(profile, COLOR_PROFILE_TYPE(profile.type));
				}
				/*
				case .CEL_EXTRA,
				case .OLD_PALETTE:
				case .OLD_PALETTE_2:
				case .MASK:
				case .TAGS:
				case .PALETTE:
				case .USER_DATA: 
				case .SLICE:
				case .PATH: //never used
				*/
				case:
					fmt.println("not doing", type, int(type), frameIndex);
			}

			current = chunkStart + int(chunk.size);
		}

		current = old + int(frame.totalBytes);
	}
	fmt.println("done");
}

read_from_buffer :: proc(dest: []byte, source: []byte, current_pos: ^int) -> bool {
	if len(source) < current_pos^ + len(dest) {
		return false;
	}
	copy(dest, source[current_pos^:current_pos^ + len(dest)]);
	current_pos^ += len(dest);

	return true;
}

read_type :: proc($T: typeid, data: []byte, current_pos: ^int) -> T {
	type: T;
	
	read_from_buffer(mem.ptr_to_bytes(&type), data, current_pos);

	return type;
}





