// Package storage provides a thin wrapper around the AWS SDK v2 S3 client
// configured to talk to a Garage (self-hosted S3-compatible) cluster.
package storage

import (
	"context"
	"fmt"
	"io"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// GarageClient wraps an S3 client pointed at a Garage cluster.
type GarageClient struct {
	s3     *s3.Client
	bucket string
}

// NewGarageClient builds a GarageClient from environment variables:
//
//	GARAGE_ENDPOINT          e.g. http://garage.garage.svc.cluster.local:3900
//	GARAGE_ACCESS_KEY_ID
//	GARAGE_SECRET_ACCESS_KEY
//	GARAGE_BUCKET            default: cove-media
func NewGarageClient(ctx context.Context) (*GarageClient, error) {
	endpoint := os.Getenv("GARAGE_ENDPOINT")
	if endpoint == "" {
		return nil, fmt.Errorf("GARAGE_ENDPOINT is required")
	}

	accessKey := os.Getenv("GARAGE_ACCESS_KEY_ID")
	if accessKey == "" {
		return nil, fmt.Errorf("GARAGE_ACCESS_KEY_ID is required")
	}

	secretKey := os.Getenv("GARAGE_SECRET_ACCESS_KEY")
	if secretKey == "" {
		return nil, fmt.Errorf("GARAGE_SECRET_ACCESS_KEY is required")
	}

	bucket := os.Getenv("GARAGE_BUCKET")
	if bucket == "" {
		bucket = "cove-media"
	}

	// Use a static credentials provider — credentials come from ESO-injected
	// env vars, not from the usual AWS credential chain.
	creds := credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")

	// Point the SDK at the Garage endpoint. Garage requires path-style
	// addressing (bucket in path, not in hostname).
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithCredentialsProvider(creds),
		config.WithRegion("garage"), // Garage ignores region but SDK requires one
	)
	if err != nil {
		return nil, fmt.Errorf("load AWS config: %w", err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = true // required by Garage
	})

	return &GarageClient{s3: client, bucket: bucket}, nil
}

// PutObject writes body to the bucket under the given key.
// contentType is passed as the S3 Content-Type metadata header.
func (g *GarageClient) PutObject(ctx context.Context, key, contentType string, body io.Reader, size int64) error {
	_, err := g.s3.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(g.bucket),
		Key:           aws.String(key),
		Body:          body,
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(size),
	})
	if err != nil {
		return fmt.Errorf("s3 PutObject %q: %w", key, err)
	}
	return nil
}
