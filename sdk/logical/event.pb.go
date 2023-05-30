// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.28.1
// 	protoc        v3.21.12
// source: sdk/logical/event.proto

package logical

import (
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	structpb "google.golang.org/protobuf/types/known/structpb"
	reflect "reflect"
	sync "sync"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

// EventPluginInfo contains data related to the plugin that generated an event.
type EventPluginInfo struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	// The type of plugin this event originated from, i.e., "auth" or "secrets.
	MountClass string `protobuf:"bytes,1,opt,name=mount_class,json=mountClass,proto3" json:"mount_class,omitempty"`
	// Unique ID of the mount entry, e.g., "kv_957bb7d8"
	MountAccessor string `protobuf:"bytes,2,opt,name=mount_accessor,json=mountAccessor,proto3" json:"mount_accessor,omitempty"`
	// Mount path of the plugin this event originated from, e.g., "secret/"
	MountPath string `protobuf:"bytes,3,opt,name=mount_path,json=mountPath,proto3" json:"mount_path,omitempty"`
	// Plugin name that this event originated from, e.g., "kv"
	Plugin string `protobuf:"bytes,4,opt,name=plugin,proto3" json:"plugin,omitempty"`
	// Plugin version of the plugin this event originated from, e.g., "v0.13.3+builtin"
	PluginVersion string `protobuf:"bytes,5,opt,name=plugin_version,json=pluginVersion,proto3" json:"plugin_version,omitempty"`
	// Mount version that this event originated from, i.e., if KVv2, then "2". Usually empty.
	Version string `protobuf:"bytes,6,opt,name=version,proto3" json:"version,omitempty"`
}

func (x *EventPluginInfo) Reset() {
	*x = EventPluginInfo{}
	if protoimpl.UnsafeEnabled {
		mi := &file_sdk_logical_event_proto_msgTypes[0]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *EventPluginInfo) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*EventPluginInfo) ProtoMessage() {}

func (x *EventPluginInfo) ProtoReflect() protoreflect.Message {
	mi := &file_sdk_logical_event_proto_msgTypes[0]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use EventPluginInfo.ProtoReflect.Descriptor instead.
func (*EventPluginInfo) Descriptor() ([]byte, []int) {
	return file_sdk_logical_event_proto_rawDescGZIP(), []int{0}
}

func (x *EventPluginInfo) GetMountClass() string {
	if x != nil {
		return x.MountClass
	}
	return ""
}

func (x *EventPluginInfo) GetMountAccessor() string {
	if x != nil {
		return x.MountAccessor
	}
	return ""
}

func (x *EventPluginInfo) GetMountPath() string {
	if x != nil {
		return x.MountPath
	}
	return ""
}

func (x *EventPluginInfo) GetPlugin() string {
	if x != nil {
		return x.Plugin
	}
	return ""
}

func (x *EventPluginInfo) GetPluginVersion() string {
	if x != nil {
		return x.PluginVersion
	}
	return ""
}

func (x *EventPluginInfo) GetVersion() string {
	if x != nil {
		return x.Version
	}
	return ""
}

// EventData contains event data in a CloudEvents container.
type EventData struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	// ID identifies the event. It is required. The combination of
	// CloudEvents Source (i.e., Vault cluster) + ID must be unique.
	// Events with the same Source + ID can be assumed to be duplicates
	// by consumers.
	// Be careful when setting this manually that the ID contains enough
	// entropy to be unique, or possibly that it is idempotent, such
	// as a hash of other fields with sufficient uniqueness.
	Id string `protobuf:"bytes,1,opt,name=id,proto3" json:"id,omitempty"`
	// Arbitrary non-secret data. Optional.
	Metadata *structpb.Struct `protobuf:"bytes,2,opt,name=metadata,proto3" json:"metadata,omitempty"`
	// Any IDs that the event relates to, i.e., UUIDs, paths.
	EntityIds []string `protobuf:"bytes,3,rep,name=entity_ids,json=entityIds,proto3" json:"entity_ids,omitempty"`
	// Human-readable note.
	Note string `protobuf:"bytes,4,opt,name=note,proto3" json:"note,omitempty"`
}

func (x *EventData) Reset() {
	*x = EventData{}
	if protoimpl.UnsafeEnabled {
		mi := &file_sdk_logical_event_proto_msgTypes[1]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *EventData) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*EventData) ProtoMessage() {}

func (x *EventData) ProtoReflect() protoreflect.Message {
	mi := &file_sdk_logical_event_proto_msgTypes[1]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use EventData.ProtoReflect.Descriptor instead.
func (*EventData) Descriptor() ([]byte, []int) {
	return file_sdk_logical_event_proto_rawDescGZIP(), []int{1}
}

func (x *EventData) GetId() string {
	if x != nil {
		return x.Id
	}
	return ""
}

func (x *EventData) GetMetadata() *structpb.Struct {
	if x != nil {
		return x.Metadata
	}
	return nil
}

func (x *EventData) GetEntityIds() []string {
	if x != nil {
		return x.EntityIds
	}
	return nil
}

func (x *EventData) GetNote() string {
	if x != nil {
		return x.Note
	}
	return ""
}

// EventReceived is used to consume events and includes additional metadata regarding
// the event type and plugin information.
type EventReceived struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Event *EventData `protobuf:"bytes,1,opt,name=event,proto3" json:"event,omitempty"`
	// namespace path
	Namespace  string           `protobuf:"bytes,2,opt,name=namespace,proto3" json:"namespace,omitempty"`
	EventType  string           `protobuf:"bytes,3,opt,name=event_type,json=eventType,proto3" json:"event_type,omitempty"`
	PluginInfo *EventPluginInfo `protobuf:"bytes,4,opt,name=plugin_info,json=pluginInfo,proto3" json:"plugin_info,omitempty"`
}

func (x *EventReceived) Reset() {
	*x = EventReceived{}
	if protoimpl.UnsafeEnabled {
		mi := &file_sdk_logical_event_proto_msgTypes[2]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *EventReceived) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*EventReceived) ProtoMessage() {}

func (x *EventReceived) ProtoReflect() protoreflect.Message {
	mi := &file_sdk_logical_event_proto_msgTypes[2]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use EventReceived.ProtoReflect.Descriptor instead.
func (*EventReceived) Descriptor() ([]byte, []int) {
	return file_sdk_logical_event_proto_rawDescGZIP(), []int{2}
}

func (x *EventReceived) GetEvent() *EventData {
	if x != nil {
		return x.Event
	}
	return nil
}

func (x *EventReceived) GetNamespace() string {
	if x != nil {
		return x.Namespace
	}
	return ""
}

func (x *EventReceived) GetEventType() string {
	if x != nil {
		return x.EventType
	}
	return ""
}

func (x *EventReceived) GetPluginInfo() *EventPluginInfo {
	if x != nil {
		return x.PluginInfo
	}
	return nil
}

var File_sdk_logical_event_proto protoreflect.FileDescriptor

var file_sdk_logical_event_proto_rawDesc = []byte{
	0x0a, 0x17, 0x73, 0x64, 0x6b, 0x2f, 0x6c, 0x6f, 0x67, 0x69, 0x63, 0x61, 0x6c, 0x2f, 0x65, 0x76,
	0x65, 0x6e, 0x74, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x07, 0x6c, 0x6f, 0x67, 0x69, 0x63,
	0x61, 0x6c, 0x1a, 0x1c, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x62, 0x75, 0x66, 0x2f, 0x73, 0x74, 0x72, 0x75, 0x63, 0x74, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x22, 0xd1, 0x01, 0x0a, 0x0f, 0x45, 0x76, 0x65, 0x6e, 0x74, 0x50, 0x6c, 0x75, 0x67, 0x69, 0x6e,
	0x49, 0x6e, 0x66, 0x6f, 0x12, 0x1f, 0x0a, 0x0b, 0x6d, 0x6f, 0x75, 0x6e, 0x74, 0x5f, 0x63, 0x6c,
	0x61, 0x73, 0x73, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x0a, 0x6d, 0x6f, 0x75, 0x6e, 0x74,
	0x43, 0x6c, 0x61, 0x73, 0x73, 0x12, 0x25, 0x0a, 0x0e, 0x6d, 0x6f, 0x75, 0x6e, 0x74, 0x5f, 0x61,
	0x63, 0x63, 0x65, 0x73, 0x73, 0x6f, 0x72, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x0d, 0x6d,
	0x6f, 0x75, 0x6e, 0x74, 0x41, 0x63, 0x63, 0x65, 0x73, 0x73, 0x6f, 0x72, 0x12, 0x1d, 0x0a, 0x0a,
	0x6d, 0x6f, 0x75, 0x6e, 0x74, 0x5f, 0x70, 0x61, 0x74, 0x68, 0x18, 0x03, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x09, 0x6d, 0x6f, 0x75, 0x6e, 0x74, 0x50, 0x61, 0x74, 0x68, 0x12, 0x16, 0x0a, 0x06, 0x70,
	0x6c, 0x75, 0x67, 0x69, 0x6e, 0x18, 0x04, 0x20, 0x01, 0x28, 0x09, 0x52, 0x06, 0x70, 0x6c, 0x75,
	0x67, 0x69, 0x6e, 0x12, 0x25, 0x0a, 0x0e, 0x70, 0x6c, 0x75, 0x67, 0x69, 0x6e, 0x5f, 0x76, 0x65,
	0x72, 0x73, 0x69, 0x6f, 0x6e, 0x18, 0x05, 0x20, 0x01, 0x28, 0x09, 0x52, 0x0d, 0x70, 0x6c, 0x75,
	0x67, 0x69, 0x6e, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x12, 0x18, 0x0a, 0x07, 0x76, 0x65,
	0x72, 0x73, 0x69, 0x6f, 0x6e, 0x18, 0x06, 0x20, 0x01, 0x28, 0x09, 0x52, 0x07, 0x76, 0x65, 0x72,
	0x73, 0x69, 0x6f, 0x6e, 0x22, 0x83, 0x01, 0x0a, 0x09, 0x45, 0x76, 0x65, 0x6e, 0x74, 0x44, 0x61,
	0x74, 0x61, 0x12, 0x0e, 0x0a, 0x02, 0x69, 0x64, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x02,
	0x69, 0x64, 0x12, 0x33, 0x0a, 0x08, 0x6d, 0x65, 0x74, 0x61, 0x64, 0x61, 0x74, 0x61, 0x18, 0x02,
	0x20, 0x01, 0x28, 0x0b, 0x32, 0x17, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x70, 0x72,
	0x6f, 0x74, 0x6f, 0x62, 0x75, 0x66, 0x2e, 0x53, 0x74, 0x72, 0x75, 0x63, 0x74, 0x52, 0x08, 0x6d,
	0x65, 0x74, 0x61, 0x64, 0x61, 0x74, 0x61, 0x12, 0x1d, 0x0a, 0x0a, 0x65, 0x6e, 0x74, 0x69, 0x74,
	0x79, 0x5f, 0x69, 0x64, 0x73, 0x18, 0x03, 0x20, 0x03, 0x28, 0x09, 0x52, 0x09, 0x65, 0x6e, 0x74,
	0x69, 0x74, 0x79, 0x49, 0x64, 0x73, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x6f, 0x74, 0x65, 0x18, 0x04,
	0x20, 0x01, 0x28, 0x09, 0x52, 0x04, 0x6e, 0x6f, 0x74, 0x65, 0x22, 0xb1, 0x01, 0x0a, 0x0d, 0x45,
	0x76, 0x65, 0x6e, 0x74, 0x52, 0x65, 0x63, 0x65, 0x69, 0x76, 0x65, 0x64, 0x12, 0x28, 0x0a, 0x05,
	0x65, 0x76, 0x65, 0x6e, 0x74, 0x18, 0x01, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x12, 0x2e, 0x6c, 0x6f,
	0x67, 0x69, 0x63, 0x61, 0x6c, 0x2e, 0x45, 0x76, 0x65, 0x6e, 0x74, 0x44, 0x61, 0x74, 0x61, 0x52,
	0x05, 0x65, 0x76, 0x65, 0x6e, 0x74, 0x12, 0x1c, 0x0a, 0x09, 0x6e, 0x61, 0x6d, 0x65, 0x73, 0x70,
	0x61, 0x63, 0x65, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x09, 0x6e, 0x61, 0x6d, 0x65, 0x73,
	0x70, 0x61, 0x63, 0x65, 0x12, 0x1d, 0x0a, 0x0a, 0x65, 0x76, 0x65, 0x6e, 0x74, 0x5f, 0x74, 0x79,
	0x70, 0x65, 0x18, 0x03, 0x20, 0x01, 0x28, 0x09, 0x52, 0x09, 0x65, 0x76, 0x65, 0x6e, 0x74, 0x54,
	0x79, 0x70, 0x65, 0x12, 0x39, 0x0a, 0x0b, 0x70, 0x6c, 0x75, 0x67, 0x69, 0x6e, 0x5f, 0x69, 0x6e,
	0x66, 0x6f, 0x18, 0x04, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x18, 0x2e, 0x6c, 0x6f, 0x67, 0x69, 0x63,
	0x61, 0x6c, 0x2e, 0x45, 0x76, 0x65, 0x6e, 0x74, 0x50, 0x6c, 0x75, 0x67, 0x69, 0x6e, 0x49, 0x6e,
	0x66, 0x6f, 0x52, 0x0a, 0x70, 0x6c, 0x75, 0x67, 0x69, 0x6e, 0x49, 0x6e, 0x66, 0x6f, 0x42, 0x28,
	0x5a, 0x26, 0x67, 0x69, 0x74, 0x68, 0x75, 0x62, 0x2e, 0x63, 0x6f, 0x6d, 0x2f, 0x68, 0x61, 0x73,
	0x68, 0x69, 0x63, 0x6f, 0x72, 0x70, 0x2f, 0x76, 0x61, 0x75, 0x6c, 0x74, 0x2f, 0x73, 0x64, 0x6b,
	0x2f, 0x6c, 0x6f, 0x67, 0x69, 0x63, 0x61, 0x6c, 0x62, 0x06, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x33,
}

var (
	file_sdk_logical_event_proto_rawDescOnce sync.Once
	file_sdk_logical_event_proto_rawDescData = file_sdk_logical_event_proto_rawDesc
)

func file_sdk_logical_event_proto_rawDescGZIP() []byte {
	file_sdk_logical_event_proto_rawDescOnce.Do(func() {
		file_sdk_logical_event_proto_rawDescData = protoimpl.X.CompressGZIP(file_sdk_logical_event_proto_rawDescData)
	})
	return file_sdk_logical_event_proto_rawDescData
}

var file_sdk_logical_event_proto_msgTypes = make([]protoimpl.MessageInfo, 3)
var file_sdk_logical_event_proto_goTypes = []interface{}{
	(*EventPluginInfo)(nil), // 0: logical.EventPluginInfo
	(*EventData)(nil),       // 1: logical.EventData
	(*EventReceived)(nil),   // 2: logical.EventReceived
	(*structpb.Struct)(nil), // 3: google.protobuf.Struct
}
var file_sdk_logical_event_proto_depIdxs = []int32{
	3, // 0: logical.EventData.metadata:type_name -> google.protobuf.Struct
	1, // 1: logical.EventReceived.event:type_name -> logical.EventData
	0, // 2: logical.EventReceived.plugin_info:type_name -> logical.EventPluginInfo
	3, // [3:3] is the sub-list for method output_type
	3, // [3:3] is the sub-list for method input_type
	3, // [3:3] is the sub-list for extension type_name
	3, // [3:3] is the sub-list for extension extendee
	0, // [0:3] is the sub-list for field type_name
}

func init() { file_sdk_logical_event_proto_init() }
func file_sdk_logical_event_proto_init() {
	if File_sdk_logical_event_proto != nil {
		return
	}
	if !protoimpl.UnsafeEnabled {
		file_sdk_logical_event_proto_msgTypes[0].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*EventPluginInfo); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_sdk_logical_event_proto_msgTypes[1].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*EventData); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_sdk_logical_event_proto_msgTypes[2].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*EventReceived); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_sdk_logical_event_proto_rawDesc,
			NumEnums:      0,
			NumMessages:   3,
			NumExtensions: 0,
			NumServices:   0,
		},
		GoTypes:           file_sdk_logical_event_proto_goTypes,
		DependencyIndexes: file_sdk_logical_event_proto_depIdxs,
		MessageInfos:      file_sdk_logical_event_proto_msgTypes,
	}.Build()
	File_sdk_logical_event_proto = out.File
	file_sdk_logical_event_proto_rawDesc = nil
	file_sdk_logical_event_proto_goTypes = nil
	file_sdk_logical_event_proto_depIdxs = nil
}